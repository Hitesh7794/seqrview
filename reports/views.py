from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from common.permissions import IsInternalAdmin
from django.utils import timezone
from django.db.models import Count, Q
from assignments.models import OperatorAssignment
from support.models import Incident

from operations.models import Exam

class DailySummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = self.request.user
        
        # Scoping logic
        assignments = OperatorAssignment.objects.all()
        incidents = Incident.objects.all()
        exams = Exam.objects.all()

        if user.user_type == 'CLIENT_ADMIN' and user.client:
            assignments = assignments.filter(shift_center__exam__client=user.client)
            incidents = incidents.filter(assignment__shift_center__exam__client=user.client)
            exams = exams.filter(client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            assignments = assignments.filter(shift_center__exam=user.exam)
            incidents = incidents.filter(assignment__shift_center__exam=user.exam)
            exams = exams.filter(pk=user.exam.pk)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            pass # Keep all
        else:
            return Response({"error": "Unauthorized"}, status=403)

        total_assigned = assignments.count()
        checked_in = assignments.filter(status='CHECK_IN').count()
        completed = assignments.filter(status='COMPLETED').count()
        pending = assignments.filter(status='PENDING').count()
        confirmed = assignments.filter(status='CONFIRMED').count()
        
        total_incidents = incidents.count()
        open_incidents = incidents.filter(status='OPEN').count()
        high_priority = incidents.filter(priority__in=['HIGH', 'CRITICAL'], status='OPEN').count()
        
        # Exam Stats
        total_exams = exams.count()
        draft_exams = exams.filter(status='DRAFT').count()
        live_exams = exams.filter(status='LIVE').count()
        completed_exams = exams.filter(status='COMPLETED').count()
        configuring_exams = exams.filter(status='CONFIGURING').count()
        
        return Response({
            "total_exams": total_exams,
            "draft": draft_exams,
            "live": live_exams,
            "completed": completed_exams,
            "configuring": configuring_exams,
            "overview": {
                "total_duties": total_assigned,
                "present": checked_in + completed,
                "pending": pending + confirmed,
                "absent": 0,
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

import csv
from django.http import HttpResponse
from attendance.models import AttendanceLog

class AttendanceExportView(APIView):
    permission_classes = [IsInternalAdmin]

    def get(self, request):
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="attendance_logs.csv"'

        writer = csv.writer(response)
        writer.writerow(['Date', 'Time', 'Operator', 'Role', 'Center', 'Activity', 'Status', 'Latitude', 'Longitude'])

        logs = AttendanceLog.objects.select_related(
            'assignment__operator', 
            'assignment__shift_center__center',
            'assignment__role'
        ).order_by('-timestamp')

        for log in logs:
            writer.writerow([
                log.timestamp.date(),
                log.timestamp.strftime('%H:%M:%S'),
                log.assignment.operator.username,
                log.assignment.role.name,
                log.assignment.shift_center.center.clientCenterName,
                log.activity_type,
                'Verified' if log.is_verified else 'Flagged',
                log.latitude,
                log.longitude
            ])

        return response
