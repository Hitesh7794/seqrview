from django.contrib import admin
from .models import OperatorAssignment

@admin.register(OperatorAssignment)
class OperatorAssignmentAdmin(admin.ModelAdmin):
    list_display = ('operator', 'shift_center', 'role', 'status', 'assignment_type')
    list_filter = ('status', 'assignment_type', 'role')
    search_fields = ('operator__username', 'operator__mobile_primary')
    autocomplete_fields = ['operator', 'shift_center', 'role']