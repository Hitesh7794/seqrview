from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.utils import timezone
from django.db.models import Count, Q
from assignments.models import OperatorAssignment
from support.models import Incident

class DailySummaryView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        today = timezone.now().date()
        
        # 1. Assignment Stats (for today's shifts)
        # Assuming ShiftCenter has a 'date' field or we filter by shift__start_time
        # In current models, ShiftCenter links to Shift (which is abstract time) + Date?
        # Let's check OperatorAssignment.assigned_at or filter mostly by created_at for now 
        # as we are in "Mock/Dev" mode. In real prod, we'd filter by Shift Date.
        # Let's filter assignments created TODAY for simplicity, or all relevant active ones.
        
        # Using 'assigned_at' implies when they were assigned. 
        # Ideally we want "Active Duties for Today".
        # Let's aggregate ALL assignments for now or filter by status.
        
        assignments = OperatorAssignment.objects.all()
        
        total_assigned = assignments.count()
        checked_in = assignments.filter(status='CHECK_IN').count()
        completed = assignments.filter(status='COMPLETED').count()
        pending = assignments.filter(status='PENDING').count()
        confirmed = assignments.filter(status='CONFIRMED').count()
        
        # 2. Incident Stats
        incidents = Incident.objects.all()
        total_incidents = incidents.count()
        open_incidents = incidents.filter(status='OPEN').count()
        high_priority = incidents.filter(priority__in=['HIGH', 'CRITICAL'], status='OPEN').count()
        
        return Response({
            "overview": {
                "total_duties": total_assigned,
                "present": checked_in + completed, # Assume completed were present
                "pending": pending + confirmed,
                "absent": 0, # To be calculated logic
                "attendance_rate": round(((checked_in + completed) / total_assigned * 100) if total_assigned else 0, 1)
            },
            "incidents": {
                "total": total_incidents,
                "open": open_incidents,
                "critical_pending": high_priority
            },
            "recent_incidents": list(incidents.order_by('-created_at')[:5].values(
                'uid', 'category__name', 'priority', 'status', 'created_at', 'assignment__operator__username'
            ))
        })
