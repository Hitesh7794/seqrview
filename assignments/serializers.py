from rest_framework import serializers
from .models import OperatorAssignment

class OperatorAssignmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = OperatorAssignment
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'assigned_at')
        depth = 3