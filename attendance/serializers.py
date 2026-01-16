from rest_framework import serializers
from .models import AttendanceLog
from assignments.models import OperatorAssignment

class AttendanceLogSerializer(serializers.ModelSerializer):
    assignment_id = serializers.UUIDField(write_only=True)
    
    class Meta:
        model = AttendanceLog
        fields = [
            'id', 'assignment_id', 'activity_type', 
            'timestamp', 'latitude', 'longitude', 
            'distance_from_center', 'is_verified', 'selfie'
        ]
        read_only_fields = ['timestamp', 'distance_from_center', 'is_verified']

    def validate_assignment_id(self, value):
        # Ensure the assignment belongs to the request user
        user = self.context['request'].user
        if not OperatorAssignment.objects.filter(uid=value, operator=user).exists():
            raise serializers.ValidationError("Invalid assignment or not assigned to you.")
        return value

    def create(self, validated_data):
        assignment_id = validated_data.pop('assignment_id')
        assignment = OperatorAssignment.objects.get(uid=assignment_id)
        return AttendanceLog.objects.create(assignment=assignment, **validated_data)