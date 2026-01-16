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
        
        # 5. Save
        # 5. Save
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        # Pass calculated values as kwargs. These are merged into validated_data by save()
        is_verified = (dist <= radius)
        self.perform_create(serializer, distance_from_center=int(dist), is_verified=is_verified)
        
        # Optional: Update Assignment Status to "ON_DUTY"
        if is_verified:
            activity_type = request.data.get('activity_type')
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