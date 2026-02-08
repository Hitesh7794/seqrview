from rest_framework import serializers
from .models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterTask
from masters.models import Client, RoleMaster

class ExamSerializer(serializers.ModelSerializer):
    client = serializers.SlugRelatedField(slug_field='uid', queryset=Client.objects.all())
    client_name = serializers.ReadOnlyField(source='client.name')
    created_by_username = serializers.ReadOnlyField(source='created_by.username')
    created_by_name = serializers.ReadOnlyField(source='created_by.full_name')
    created_by_role = serializers.ReadOnlyField(source='created_by.user_type')

    class Meta:
        model = Exam
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'created_by', 'updated_by')

class ShiftSerializer(serializers.ModelSerializer):
    exam = serializers.SlugRelatedField(slug_field='uid', queryset=Exam.objects.all())

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
    exam_center_details = ExamCenterSerializer(source='exam_center', read_only=True)
    shift_details = ShiftSerializer(source='shift', read_only=True)

    class Meta:
        model = ShiftCenter
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')

class ShiftCenterTaskSerializer(serializers.ModelSerializer):
    shift_center = serializers.SlugRelatedField(slug_field='uid', queryset=ShiftCenter.objects.all())
    role = serializers.SlugRelatedField(slug_field='uid', queryset=RoleMaster.objects.all())

    class Meta:
        model = ShiftCenterTask
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')
