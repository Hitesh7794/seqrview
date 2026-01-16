from rest_framework import serializers
from .models import IncidentCategory, Incident, IncidentAttachment
from assignments.models import OperatorAssignment

class IncidentCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = IncidentCategory
        fields = ['id', 'uid', 'name', 'description']

class IncidentAttachmentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = IncidentAttachment
        fields = ['id', 'uid', 'file', 'file_url', 'caption', 'created_at']
        read_only_fields = ['created_at']

    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and hasattr(obj.file, 'url'):
            return request.build_absolute_uri(obj.file.url) if request else obj.file.url
        return None

class IncidentSerializer(serializers.ModelSerializer):
    # Writable fields
    assignment_id = serializers.UUIDField(write_only=True)
    category_id = serializers.UUIDField(write_only=True)
    
    # Read-only nested representations
    category = IncidentCategorySerializer(read_only=True)
    attachments = IncidentAttachmentSerializer(many=True, read_only=True)
    
    # File Uploads (Write only)
    # We accept a list of files for 'attachments'
    # handled in create()
    
    class Meta:
        model = Incident
        fields = [
            'id', 'uid', 
            'assignment_id', 'category_id', 
            'priority', 'status', 'description', 
            'resolution_notes', 'resolved_at',
            'category', 'attachments', 'created_at'
        ]
        read_only_fields = [
            'status', 'resolution_notes', 'resolved_at', 
            'created_at', 'attachments'
        ]

    def validate_assignment_id(self, value):
        user = self.context['request'].user
        # Ensure assignment exists and belongs to user
        # Also maybe check if it's ACTIVE or COMPLETED? 
        # For now, just ownership check is enough.
        if not OperatorAssignment.objects.filter(uid=value, operator=user).exists():
            raise serializers.ValidationError("Invalid assignment or not assigned to you.")
        return value

    def create(self, validated_data):
        assignment_id = validated_data.pop('assignment_id')
        category_id = validated_data.pop('category_id')
        
        assignment = OperatorAssignment.objects.get(uid=assignment_id)
        category = IncidentCategory.objects.get(uid=category_id)
        
        incident = Incident.objects.create(
            assignment=assignment,
            category=category,
            **validated_data
        )
        
        # Handle File Uploads manually from context request
        request = self.context.get('request')
        if request and request.FILES:
            # Look for keys like 'attachments' or just iterate structure
            # Frontend should send 'attachments' as list of files
            files = request.FILES.getlist('attachments')
            for f in files:
                IncidentAttachment.objects.create(incident=incident, file=f)
                
        return incident
