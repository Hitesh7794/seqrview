from rest_framework import serializers
from .models import Client, CenterMaster, RoleMaster, TaskLibrary

class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Client
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'exam_count', 'exam_active_count')

class CenterMasterSerializer(serializers.ModelSerializer):
    client_code = serializers.ReadOnlyField(source='client.client_code')

    class Meta:
        model = CenterMaster
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at', 'total_exams_conducted', 'last_exam_date')

class RoleMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoleMaster
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')

class TaskLibrarySerializer(serializers.ModelSerializer):
    class Meta:
        model = TaskLibrary
        fields = '__all__'
        read_only_fields = ('uid', 'created_at', 'updated_at')
