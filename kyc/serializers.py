from rest_framework import serializers


class AadhaarStartSerializer(serializers.Serializer):
    id_number = serializers.CharField(min_length=12, max_length=12)


class AadhaarSubmitOtpSerializer(serializers.Serializer):
    kyc_session_uid = serializers.UUIDField()
    otp = serializers.CharField(min_length=4, max_length=10)


class KycSessionUidSerializer(serializers.Serializer):
    kyc_session_uid = serializers.UUIDField()


class AadhaarVerifyDetailsSerializer(serializers.Serializer):
    kyc_session_uid = serializers.UUIDField()
    full_name = serializers.CharField(max_length=200, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    gender = serializers.CharField(max_length=10, required=False, allow_blank=True)
    state = serializers.CharField(max_length=100, required=False, allow_blank=True)
    district = serializers.CharField(max_length=100, required=False, allow_blank=True)
    address = serializers.CharField(max_length=255, required=False, allow_blank=True)


class DLStartSerializer(serializers.Serializer):
    license_number = serializers.CharField(min_length=5, max_length=20)
    dob = serializers.DateField()


class DLVerifyDetailsSerializer(serializers.Serializer):
    kyc_session_uid = serializers.UUIDField()
    full_name = serializers.CharField(max_length=200, required=False, allow_blank=True)
    gender = serializers.CharField(max_length=10, required=False, allow_blank=True)
    state = serializers.CharField(max_length=100, required=False, allow_blank=True)
    district = serializers.CharField(max_length=100, required=False, allow_blank=True)
    address = serializers.CharField(max_length=255, required=False, allow_blank=True)
    # Note: date_of_birth not needed - already collected at DL input screen and stored in session
