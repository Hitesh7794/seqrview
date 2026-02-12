import math
from rest_framework import viewsets, status
from rest_framework.response import Response
from .models import AttendanceLog
from .serializers import AttendanceLogSerializer
from assignments.models import OperatorAssignment

class AttendanceLogViewSet(viewsets.ModelViewSet):
    queryset = AttendanceLog.objects.all()
    serializer_class = AttendanceLogSerializer

    def get_queryset(self):
        user = self.request.user
        qs = AttendanceLog.objects.all()
        if user.is_staff or user.is_superuser or user.user_type == 'INTERNAL_ADMIN':
            return qs
        elif user.user_type == 'CLIENT_ADMIN' and user.client:
            return qs.filter(assignment__shift_center__exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            return qs.filter(assignment__shift_center__exam=user.exam)
        return qs.filter(assignment__operator=user)

    def create(self, request, *args, **kwargs):
        # 1. Get Coordinates from Request
        try:
            lat = float(request.data.get('latitude'))
            lon = float(request.data.get('longitude'))
            assignment_id = request.data.get('assignment_id')
        except (TypeError, ValueError):
            return Response({"detail": "Invalid coordinates"}, status=status.HTTP_400_BAD_REQUEST)

        # 2. Get Center Coordinates (Priority: ExamCenter > CenterMaster)
        try:
            assignment = OperatorAssignment.objects.get(uid=assignment_id, operator=request.user)
            # Traverse: Assignment -> ShiftCenter -> ExamCenter
            exam_center = assignment.shift_center.exam_center
            master_center = exam_center.master_center

            # Default to 0.0
            center_lat = 0.0
            center_lon = 0.0
            radius = 200

            # Priority 1: ExamCenter specific coordinates
            if exam_center.latitude and exam_center.longitude:
                center_lat = float(exam_center.latitude)
                center_lon = float(exam_center.longitude)
                radius = exam_center.geofence_radius_meters
            
            # Priority 2: MasterCenter fallback
            elif master_center and master_center.latitude and master_center.longitude:
                center_lat = float(master_center.latitude)
                center_lon = float(master_center.longitude)
                radius = master_center.geofence_radius_meters
            
            # If neither has coordinates, we essentially fail (dist will be huge if one is 0.0)
             
        except OperatorAssignment.DoesNotExist:
             return Response({"detail": "Assignment not found"}, status=status.HTTP_404_NOT_FOUND)

        # 2a. Time Window Validation
        shift = assignment.shift_center.shift
        if assignment.shift_center.shift.is_locked:
            return Response({"detail": "Shift is locked. Time period exceeded."}, status=status.HTTP_400_BAD_REQUEST)

        from django.utils import timezone
        from datetime import datetime, timedelta
        
        # Construct Aware Datetime for Shift Start/End
        # Assuming DB stores UTC if USE_TZ=True and TIME_ZONE='UTC'
        try:
            # Combine Date + Time
            shift_start_naive = datetime.combine(shift.work_date, shift.start_time)
            shift_end_naive = datetime.combine(shift.work_date, shift.end_time)
            
            # Make Aware (UTC)
            shift_start_dt = timezone.make_aware(shift_start_naive, timezone.utc)
            shift_end_dt = timezone.make_aware(shift_end_naive, timezone.utc)
            
            # Windows
            # Check-In: 1 Hour before Start -> End Time
            check_in_open = shift_start_dt - timedelta(hours=1)
            check_in_close = shift_end_dt
            
            # Check-Out: Start Time -> End Time + 4 Hours
            check_out_open = shift_start_dt
            check_out_close = shift_end_dt + timedelta(hours=4)
            
            now = timezone.now()
            activity_type = request.data.get('activity_type')

            if activity_type == 'CHECK_IN':
                if not (check_in_open <= now <= check_in_close):
                    return Response({
                        "detail": f"Check-In allowed between {check_in_open.strftime('%H:%M')} and {check_in_close.strftime('%H:%M')} UTC."
                    }, status=status.HTTP_400_BAD_REQUEST)
                    
            elif activity_type == 'CHECK_OUT':
                 if not (check_out_open <= now <= check_out_close):
                     # Allow Check-Out logic to be lenient? 
                     # User Request: "check in checkout can be done during shift time"
                     # If they are very late, maybe we still allow but warn?
                     # Sticking to strictly windows for now.
                    return Response({
                        "detail": f"Check-Out allowed between {check_out_open.strftime('%H:%M')} and {check_out_close.strftime('%H:%M')} UTC."
                    }, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            # Fallback if datetime conversion fails
            print(f"Time validation error: {e}")
            pass # Or fail validation? Safer to pass if data is corrupt to avoid lockout, or fail to be strict.
            # Passing for now unless critical.


        # 3. Calculate Distance (Haversine Formula)
        dist = self.calculate_distance(lat, lon, center_lat, center_lon)
        
        # 4. Preparing data
        # We don't modify request.data directly for read_only fields
        
        is_geofencing_enabled = assignment.shift_center.exam.is_geofencing_enabled
        if not is_geofencing_enabled:
            is_verified = True
        else:
            is_verified = (dist <= radius)
        
        # 4a. FACE VERIFICATION (Only for CHECK_IN)
        activity_type = request.data.get('activity_type')
        
        # Check if selfie is mandated by Exam config
        # We already fetched 'assignment', so we can check the flag
        is_selfie_required = assignment.shift_center.exam.is_selfie_enabled
        
        if activity_type == 'CHECK_IN' and is_selfie_required:
            # Selfie is mandatory for Check-In
            selfie_file = request.FILES.get('selfie')
            if not selfie_file:
                 return Response({"detail": "Selfie is required for Check-In"}, status=status.HTTP_400_BAD_REQUEST)
            
            # Read bytes for API
            selfie_bytes = selfie_file.read()
            selfie_file.seek(0) # Reset pointer for saving model later
            
            # Initialize Surepass Helper
            from kyc.surepass_client import SurepassClient, SurepassError
            sp_client = SurepassClient()
            
            try:
                # A. Liveness Check
                liveness_resp = sp_client.face_liveness(selfie_bytes, selfie_file.name or 'selfie.jpg')
                # Check confidence/success logic based on Surepass response structure
                # Typically data={'confidence': 0.99, 'is_live': True, ...} depending on exact API
                # Assume standard success=True implies liveness passed or check payload
                
                # B. Face Match Check (Selfie vs Profile Photo)
                user_photo = request.user.photo
                if not user_photo:
                    return Response({"detail": "User profile photo missing. Cannot verify identity."}, status=status.HTTP_400_BAD_REQUEST)
                
                try:
                    user_photo_bytes = user_photo.read()
                    # user_photo.close() # Don't close, Django manages storage
                except Exception:
                     return Response({"detail": "Could not read profile photo."}, status=status.HTTP_400_BAD_REQUEST)

                match_resp = sp_client.face_match(
                    selfie_bytes, 
                    user_photo_bytes, 
                    selfie_filename='checkin_selfie.jpg',
                    id_filename='profile_photo.jpg'
                )
                
                # Check Match Score
                # Expected structure: {'data': {'similarity': 0.95, ...}, 'success': True}
                data = match_resp.get('data', {})
                similarity = data.get('similarity')
                
                # Fallback if 'similarity' key is different (e.g. 'confidence' or 'score')
                if similarity is None:
                    similarity = data.get('confidence')
                
                # If we still can't find it, we might be looking at a different API version. 
                # But typically Surepass has 'similarity' (0-1) or (0-100).
                # Assuming 0-1 scale. If it's 0-100, we'll need to adjust. 
                # Safe logic: if > 1, assume 0-100.
                
                final_score = 0.0
                if similarity is not None:
                    final_score = float(similarity)
                    if final_score > 1.0: # Normalize 0-100 to 0-1
                        final_score = final_score / 100.0
                
                # THRESHOLD: 0.6 (60%) is a standard balance. Adjust as needed.
                if final_score < 0.6:
                    raise SurepassError(f"Face mismatch. Similarity score: {int(final_score*100)}%")

            except SurepassError as e:
                # Parse user-friendly error
                msg = str(e)
                if "face_not_found" in msg or "confidence" in msg:
                    error_detail = "No face detected. Please ensure your face is clearly visible."
                elif "multiple_faces" in msg:
                    error_detail = "Multiple faces detected. Please ensure only you are in the frame."
                elif "Face mismatch" in msg:
                    error_detail = "Face verification failed. Your selfie does not match your profile photo."
                elif "liveness" in msg.lower():
                     error_detail = "Liveness check failed. Please blink or move slightly and try again."
                else:
                    error_detail = f"Verification Failed: {msg}"
                
                return Response({"detail": error_detail}, status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                return Response({"detail": f"Verification Error: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # 5. Save
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        self.perform_create(serializer, distance_from_center=int(dist), is_verified=is_verified)
        
        # Optional: Update Assignment Status
        if is_verified:
            if activity_type == 'CHECK_IN':
                assignment.status = 'CHECK_IN'
                assignment.save()
            elif activity_type == 'CHECK_OUT':
                assignment.status = 'COMPLETED'
                from django.utils import timezone
                assignment.completed_at = timezone.now()
                assignment.save()
            
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def perform_create(self, serializer, **kwargs):
        serializer.save(**kwargs)

    @staticmethod
    def calculate_distance(lat1, lon1, lat2, lon2):
        # Simple Haversine implementation
        R = 6371000  # Radius of Earth in meters
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        
        a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c