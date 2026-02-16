from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import OperatorAssignment, AssignmentTask, AssignmentTaskEvidence
from operations.models import ShiftCenter
from masters.models import RoleMaster

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

class OperatorAssignmentSerializer(serializers.ModelSerializer):
    tasks = AssignmentTaskSerializer(many=True, read_only=True)
    check_in_at = serializers.SerializerMethodField()
    check_out_at = serializers.SerializerMethodField()
    
    class Meta:
        model = OperatorAssignment
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'assigned_at')
        depth = 3

    def get_check_in_at(self, obj):
        log = obj.attendance_logs.filter(activity_type='CHECK_IN').order_by('timestamp').first()
        return log.timestamp if log else None

    def get_check_out_at(self, obj):
        log = obj.attendance_logs.filter(activity_type='CHECK_OUT').order_by('-timestamp').first()
        return log.timestamp if log else None

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

    def validate(self, attrs):
        operator = attrs.get('operator')
        shift_center = attrs.get('shift_center')
        
        if operator and shift_center:
            # 0. Check for Locked Shift
            if shift_center.shift.is_locked:
                raise serializers.ValidationError(
                    f"Cannot assign operator. The shift '{shift_center.shift.shift_code}' is locked (past end time)."
                )

            # Check for existing active assignment in the entire shift (across all centers)
            exists = OperatorAssignment.objects.filter(
                operator=operator,
                shift_center__shift=shift_center.shift
            ).exclude(status='CANCELLED').exists()
            
            if exists:
                raise serializers.ValidationError(
                    f"Operator {operator.username} is already assigned to another center in this shift ({shift_center.shift.shift_code})."
                )
        return attrs
