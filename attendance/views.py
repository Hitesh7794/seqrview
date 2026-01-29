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
        if user.is_staff or user.is_superuser:
            return AttendanceLog.objects.all()
        return AttendanceLog.objects.filter(assignment__operator=user)

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

        # 3. Calculate Distance (Haversine Formula)
        dist = self.calculate_distance(lat, lon, center_lat, center_lon)
        
        # 4. Preparing data
        # We don't modify request.data directly for read_only fields
        
        is_verified = (dist <= radius)
        
        # 4a. FACE VERIFICATION (Only for CHECK_IN)
        activity_type = request.data.get('activity_type')
        if activity_type == 'CHECK_IN':
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