from django.contrib import admin
from .models import Client, CenterMaster, RoleMaster

@admin.register(Client)
class ClientAdmin(admin.ModelAdmin):
    list_display = ('client_code', 'name', 'status', 'exam_active_count', 'city')
    search_fields = ('name', 'client_code', 'city')
    list_filter = ('status', 'state')
    readonly_fields = ('exam_count', 'exam_active_count')

@admin.register(CenterMaster)
class CenterMasterAdmin(admin.ModelAdmin):
    list_display = ('center_code', 'name', 'client', 'city', 'status', 'rating', 'total_computers_functional')
    search_fields = ('name', 'center_code', 'city', 'pincode')
    list_filter = ('status', 'client', 'ownership_type', 'state')
    
@admin.register(RoleMaster)
class RoleMasterAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'gender_requirement', 'is_active')
    search_fields = ('name', 'code')
    list_filter = ('is_active', 'gender_requirement')