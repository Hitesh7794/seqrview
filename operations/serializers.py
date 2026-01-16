from rest_framework import serializers
from .models import Exam, Shift, ExamCenter, ShiftCenter

class ExamSerializer(serializers.ModelSerializer):
    class Meta:
        model = Exam
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'created_by', 'updated_by')

class ShiftSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shift
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'created_by', 'updated_by')

class ExamCenterSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExamCenter
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')

class ShiftCenterSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShiftCenter
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')