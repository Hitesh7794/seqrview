from rest_framework import serializers
from .models import AppUser

from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from operators.models import OperatorProfile




class MeSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppUser
        fields = ["uid", "username", "email", "first_name", "last_name", "middle_name", "full_name", "user_type", "status", "mobile_primary", "photo"]


class MeUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppUser
        fields = ["email", "first_name", "last_name", "middle_name", "mobile_primary"]

User = get_user_model()


class RegisterOperatorSerializer(serializers.Serializer):
    
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(min_length=8, write_only=True)

    email = serializers.EmailField(required=False, allow_null=True, allow_blank=True)
    first_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    last_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    mobile_primary = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    def validate_username(self, value: str) -> str:
        
        v = value.strip().lower()
        if User.objects.filter(username=v).exists():
            raise serializers.ValidationError("Username already exists")
        return v

    def create(self, validated_data):
        password = validated_data.pop("password")

        
        validated_data["user_type"] = "OPERATOR"
        validated_data.setdefault("status", "ONBOARDING")

        
        user = User.objects.create_user(password=password, **validated_data)

        
        OperatorProfile.objects.get_or_create(user=user)

        return user

    def to_representation(self, user):
        
        refresh = RefreshToken.for_user(user)
        return {
            "user": {
                "uid": str(getattr(user, "uid", "")),
                "username": user.username,
                "user_type": getattr(user, "user_type", None),
                "status": getattr(user, "status", None),
            },
            "tokens": {
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            },
        }


class AdminCreateUserSerializer(serializers.Serializer):
    # have power can create any type of user
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(min_length=8, write_only=True)

    user_type = serializers.ChoiceField(choices=["OPERATOR", "CLIENT_ADMIN", "CLIENT_VIEWER", "INTERNAL_ADMIN"])
    status = serializers.ChoiceField(choices=["ACTIVE", "BLACKLIST", "INACTIVE", "ONBOARDING", "PENDING_APPROVAL", "REJECTED", "REQUESTED"], required=False)

    email = serializers.EmailField(required=False, allow_null=True, allow_blank=True)
    first_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    last_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    mobile_primary = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    
    client_uid = serializers.UUIDField(required=False)

    def validate_username(self, value: str) -> str:
        v = value.strip().lower()
        if User.objects.filter(username=v).exists():
            raise serializers.ValidationError("Username already exists")
        return v

    def create(self, validated_data):
        password = validated_data.pop("password")
        user_type = validated_data.get("user_type")

        
        validated_data.setdefault("status", "ACTIVE")

        user = User.objects.create_user(password=password, **validated_data)

        
        if user_type == "OPERATOR":
            OperatorProfile.objects.get_or_create(user=user)

        return user

    def to_representation(self, user):
        return {
            "uid": str(getattr(user, "uid", "")),
            "username": user.username,
            "user_type": getattr(user, "user_type", None),
            "status": getattr(user, "status", None),
        }
    
class OperatorOtpRequestSerializer(serializers.Serializer):
    mobile = serializers.CharField(min_length=8, max_length=15)

class OperatorOtpVerifySerializer(serializers.Serializer):
    otp_session_uid = serializers.UUIDField()
    otp = serializers.CharField(min_length=4, max_length=10)