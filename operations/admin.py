from django.contrib import admin
from .models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterRole

class ShiftInline(admin.TabularInline):
    model = Shift
    extra = 0
    fields = ('shift_code', 'work_date', 'start_time', 'end_time', 'status')

@admin.register(Exam)
class ExamAdmin(admin.ModelAdmin):
    list_display = ('exam_code', 'name', 'client', 'exam_start_date', 'status')
    list_filter = ('status', 'client', 'exam_type')
    search_fields = ('name', 'exam_code')
    inlines = [ShiftInline]

@admin.register(Shift)
class ShiftAdmin(admin.ModelAdmin):
    list_display = ('shift_code', 'exam', 'work_date', 'start_time', 'status')
    list_filter = ('status', 'shift_type', 'work_date')
    search_fields = ('shift_code', 'exam__name')

@admin.register(ExamCenter)
class ExamCenterAdmin(admin.ModelAdmin):
    list_display = ('client_center_code', 'client_center_name', 'exam', 'active_capacity', 'status')
    list_filter = ('status', 'exam')
    search_fields = ('client_center_name', 'client_center_code', 'exam__name')

@admin.register(ShiftCenter)
class ShiftCenterAdmin(admin.ModelAdmin):
    list_display = ('exam', 'shift', 'exam_center', 'status')
    list_filter = ('status', 'shift__work_date')
    search_fields = ('exam__name', 'exam_center__client_center_name')

@admin.register(ShiftCenterRole)
class ShiftCenterRoleAdmin(admin.ModelAdmin):
    list_display = ('shift_center', 'role', 'headcount', 'buffer_headcount')
    list_filter = ('role',)