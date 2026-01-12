import secrets

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from rest_framework_simplejwt.tokens import RefreshToken

from operators.models import OperatorProfile
from .models import OtpSession
from .permissions import IsInternalAdmin
from .serializers import (
    RegisterOperatorSerializer,
    AdminCreateUserSerializer,
    MeSerializer,
    MeUpdateSerializer,
    OperatorOtpRequestSerializer,
    OperatorOtpVerifySerializer,
)

User = get_user_model()

def _normalize_mobile(m: str) -> str:
    """Store/search mobile in a canonical form: last 10 digits."""
    digits = "".join(ch for ch in (m or "") if ch.isdigit())
    if len(digits) >= 10:
        digits = digits[-10:]
    return digits


def _generate_operator_username(mobile_10: str) -> str:
    """Collision-safe username generator."""
    suffix = mobile_10[-6:] if len(mobile_10) >= 6 else mobile_10
    rand = secrets.token_hex(3)  # 6 hex chars
    return f"op_{suffix}_{rand}"



class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(MeSerializer(request.user).data, status=status.HTTP_200_OK)

    def patch(self, request):
        ser = MeUpdateSerializer(request.user, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(MeSerializer(request.user).data, status=status.HTTP_200_OK)


class RegisterOperatorView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = RegisterOperatorSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        return Response(ser.to_representation(user), status=status.HTTP_201_CREATED)


class AdminCreateUserView(APIView):
    permission_classes = [IsInternalAdmin]

    def post(self, request):
        ser = AdminCreateUserSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        return Response(ser.to_representation(user), status=status.HTTP_201_CREATED)


class OperatorOtpRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = OperatorOtpRequestSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        mobile = _normalize_mobile(ser.validated_data["mobile"])
        if len(mobile) != 10:
            return Response({"detail": "Invalid mobile number"}, status=status.HTTP_400_BAD_REQUEST)

        
        user = (
            User.objects.filter(user_type="OPERATOR", mobile_primary=mobile)
            .order_by("-created_at")
            .first()
        )

        
        if not user:
            user = None
            for _ in range(7): 
                username = _generate_operator_username(mobile)
                try:
                    with transaction.atomic():
                        user = User.objects.create_user(
                            username=username,
                            password=None,
                            user_type="OPERATOR",
                            status="ONBOARDING",
                            mobile_primary=mobile,
                        )
                       
                        user.set_unusable_password()
                        user.save(update_fields=["password"])

                        OperatorProfile.objects.get_or_create(user=user)
                    break
                except IntegrityError:
                    
                    existing = (
                        User.objects.filter(user_type="OPERATOR", mobile_primary=mobile)
                        .order_by("-created_at")
                        .first()
                    )
                    if existing:
                        user = existing
                        break
                    user = None
                    continue

            if not user:
                return Response(
                    {"detail": "Could not create operator. Please try again."},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

       
        otp = OtpSession.generate_otp()
        sess = OtpSession.objects.create(
            mobile=mobile,
            otp_hash=OtpSession._hash_otp(mobile, otp),
            expires_at=OtpSession.default_expiry(),
        )

        # TODO: send OTP via SMS gateway
        print(f"[DEV OTP] mobile={mobile} otp={otp} session={sess.uid}")

        return Response(
            {"otp_session_uid": str(sess.uid), "expires_at": sess.expires_at, "status": "OTP_SENT"},
            status=status.HTTP_200_OK,
        )



class OperatorOtpVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = OperatorOtpVerifySerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        session_uid = ser.validated_data["otp_session_uid"]
        otp = str(ser.validated_data["otp"]).strip()

        max_attempts = getattr(settings, "OTP_MAX_ATTEMPTS", 5)

        
        with transaction.atomic():
            sess = OtpSession.objects.select_for_update().filter(uid=session_uid).first()

            if not sess:
                return Response({"detail": "Invalid otp session"}, status=status.HTTP_404_NOT_FOUND)
            if sess.verified_at:
                return Response({"detail": "OTP already used"}, status=status.HTTP_400_BAD_REQUEST)
            if sess.is_expired():
                return Response({"detail": "OTP expired"}, status=status.HTTP_400_BAD_REQUEST)
            if sess.attempts >= max_attempts:
                return Response({"detail": "Too many attempts"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

            expected = OtpSession._hash_otp(sess.mobile, otp)
            if expected != sess.otp_hash:
                sess.attempts += 1
                sess.save(update_fields=["attempts", "updated_at"])
                return Response({"detail": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)

            
            sess.verified_at = timezone.now()
            sess.save(update_fields=["verified_at", "updated_at"])

       
        user = (
            User.objects.filter(user_type="OPERATOR", mobile_primary=sess.mobile)
            .order_by("-created_at")
            .first()
        )
        if not user:
            return Response({"detail": "Operator not found"}, status=status.HTTP_404_NOT_FOUND)

        
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "user": {
                    "uid": str(getattr(user, "uid", "")),
                    "username": user.username,
                    "mobile_primary": user.mobile_primary,
                },
                "tokens": {"refresh": str(refresh), "access": str(refresh.access_token)},
            },
            status=status.HTTP_200_OK,
        )
