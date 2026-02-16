from rest_framework import serializers
from .models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterTask
from masters.models import Client, RoleMaster

class ExamSerializer(serializers.ModelSerializer):
    client = serializers.SlugRelatedField(slug_field='uid', queryset=Client.objects.all())
    client_name = serializers.ReadOnlyField(source='client.name')
    created_by_username = serializers.ReadOnlyField(source='created_by.username')
    created_by_name = serializers.ReadOnlyField(source='created_by.full_name')
    created_by_role = serializers.ReadOnlyField(source='created_by.user_type')

    is_locked = serializers.BooleanField(read_only=True)

    class Meta:
        model = Exam
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'created_by', 'updated_by', 'is_locked')

    def validate(self, attrs):
        if self.instance and self.instance.is_locked:
            raise serializers.ValidationError(
                f"Cannot modify exam '{self.instance.name}'. It is locked because the end date has passed."
            )
        return attrs

class ShiftSerializer(serializers.ModelSerializer):
    exam = serializers.SlugRelatedField(slug_field='uid', queryset=Exam.objects.all())
    centers_count = serializers.IntegerField(read_only=True)

    is_locked = serializers.BooleanField(read_only=True)

    class Meta:
        model = Shift
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'created_by', 'updated_by', 'centers_count', 'is_locked')

    def validate(self, attrs):
        # 1. Check if Exam is Locked
        exam = attrs.get('exam')
        if not exam and self.instance:
            exam = self.instance.exam
            
        if exam and exam.is_locked:
            raise serializers.ValidationError(
                f"Cannot modify shift. The exam '{exam.name}' is locked (past end date)."
            )
            
        # 2. Check if Shift ITSELF is Locked (for updates)
        if self.instance and self.instance.is_locked:
             raise serializers.ValidationError(
                f"Cannot modify this shift. It is locked because the shift time has passed."
            )
            
        return attrs

class ExamCenterSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExamCenter
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')

class ShiftCenterSerializer(serializers.ModelSerializer):
    exam_center_details = ExamCenterSerializer(source='exam_center', read_only=True)
    shift_details = ShiftSerializer(source='shift', read_only=True)
    tasks_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = ShiftCenter
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'tasks_count')

    def validate(self, attrs):
        # Check if Shift is locked when creating/updating shift center
        shift = attrs.get('shift')
        if not shift and self.instance:
            shift = self.instance.shift
            
        if shift and shift.is_locked:
             raise serializers.ValidationError(
                f"Cannot modify centers. The shift '{shift.shift_code}' is locked (past end time)."
            )
        return attrs

class ShiftCenterTaskSerializer(serializers.ModelSerializer):
    shift_center = serializers.SlugRelatedField(slug_field='uid', queryset=ShiftCenter.objects.all())
    role = serializers.SlugRelatedField(slug_field='uid', queryset=RoleMaster.objects.all())

    class Meta:
        model = ShiftCenterTask
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')
