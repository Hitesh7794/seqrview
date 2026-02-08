from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import OperatorAssignment, AssignmentTask, AssignmentTaskEvidence
from operations.models import ShiftCenter
from masters.models import RoleMaster

class OperatorAssignmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = OperatorAssignment
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'assigned_at')
        depth = 3

class OperatorAssignmentCreateSerializer(serializers.ModelSerializer):
    shift_center = serializers.SlugRelatedField(
        slug_field='uid', 
        queryset=ShiftCenter.objects.all()
    )
    operator = serializers.SlugRelatedField(
        slug_field='uid', 
        queryset=get_user_model().objects.filter(user_type='OPERATOR')
    )
    role = serializers.SlugRelatedField(
        slug_field='uid', 
        queryset=RoleMaster.objects.all()
    )

    class Meta:
        model = OperatorAssignment
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'assigned_at')

class AssignmentTaskEvidenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = AssignmentTaskEvidence
        fields = '__all__'

class AssignmentTaskSerializer(serializers.ModelSerializer):
    task_name = serializers.ReadOnlyField(source='shift_center_task.task_name')
    task_type = serializers.ReadOnlyField(source='shift_center_task.task_type')
    description = serializers.ReadOnlyField(source='shift_center_task.description') 
    is_mandatory = serializers.ReadOnlyField(source='shift_center_task.is_mandatory')
    
    evidence_files = AssignmentTaskEvidenceSerializer(source='evidence', many=True, read_only=True)

    class Meta:
        model = AssignmentTask
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'evidence_files')
