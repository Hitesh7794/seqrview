from django.contrib import admin
from .models import IncidentCategory, Incident, IncidentAttachment

@admin.register(IncidentCategory)
class IncidentCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active', 'created_at')
    search_fields = ('name',)
    list_filter = ('is_active',)

class AttachmentInline(admin.TabularInline):
    model = IncidentAttachment
    extra = 0
    readonly_fields = ('file', 'created_at')

@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = ('category', 'get_operator', 'priority', 'status', 'created_at')
    list_filter = ('status', 'priority', 'category', 'created_at')
    search_fields = ('assignment__operator__username', 'description', 'resolution_notes')
    readonly_fields = ('created_at', 'updated_at')
    inlines = [AttachmentInline]
    
    def get_operator(self, obj):
        return obj.assignment.operator.username
    get_operator.short_description = 'Operator'

    def save_model(self, request, obj, form, change):
        # Auto-set resolved_by if status changes to RESOLVED/CLOSED
        if change and obj.status in ['RESOLVED', 'CLOSED'] and not obj.resolved_by:
            obj.resolved_by = request.user
            from django.utils import timezone
            if not obj.resolved_at:
                obj.resolved_at = timezone.now()
        super().save_model(request, obj, form, change)
