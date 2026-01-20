from django.urls import path
from .views import DailySummaryView, AttendanceExportView

urlpatterns = [
    path('summary/', DailySummaryView.as_view(), name='daily-summary'),
    path('export/attendance/', AttendanceExportView.as_view(), name='export-attendance'),
]
