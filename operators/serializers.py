from rest_framework import serializers
from .models import OperatorProfile


class OperatorProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = OperatorProfile
        
        fields = [
            "uid",
            "date_of_birth",
            "gender",

            "current_address",
            "current_state",
            "current_zip",
            "current_district",
            "current_lat",
            "current_lng",

            "permanent_address",
            "permanent_state",
            "permanent_zip",
            "permanent_district",

            "profile_status",
            "verification_method",
            "kyc_status",
            "kyc_verified_at",
            "kyc_fail_reason",
        ]
        read_only_fields = ["uid", "profile_status", "verification_method", "kyc_status", "kyc_verified_at", "kyc_fail_reason"]
