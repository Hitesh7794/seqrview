from django.contrib import admin
from .models import AttendanceLog

@admin.register(AttendanceLog)
class AttendanceLogAdmin(admin.ModelAdmin):
    list_display = ('id', 'assignment', 'activity_type', 'timestamp', 'distance_from_center', 'is_verified')
    list_filter = ('activity_type', 'is_verified', 'timestamp')
    search_fields = ('assignment__operator__username', 'assignment__operator__email')
    readonly_fields = ('timestamp', 'latitude', 'longitude', 'distance_from_center', 'is_verified')