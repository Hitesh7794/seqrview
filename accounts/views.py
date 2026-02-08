import secrets
import csv
import io
from django.http import HttpResponse

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework.decorators import action

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
    AppUserSerializer,
)

User = get_user_model()

import re

def _normalize_mobile(m: str) -> str:
    """Store/search mobile in a canonical form: last 10 digits."""
    digits = "".join(ch for ch in (m or "") if ch.isdigit())
    if len(digits) >= 10:
        digits = digits[-10:]
    return digits


def is_valid_indian_mobile(mobile: str) -> bool:
    """Check if the string matches Indian mobile number regex (10 digits starting with 6-9)."""
    pattern = r'^[6789]\d{9}$'
    return bool(re.match(pattern, mobile))


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
        if not is_valid_indian_mobile(mobile):
            return Response({"detail": "Invalid Indian mobile number. Must be 10 digits starting with 6-9."}, status=status.HTTP_400_BAD_REQUEST)

        
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

        # Call AuthKey API
        from .utils import send_authkey_otp
        api_resp = send_authkey_otp(mobile, otp)

        print(f"[DEV OTP] mobile={mobile} otp={otp} session={sess.uid} authkey_resp={api_resp}")

        return Response(
            {
                "otp_session_uid": str(sess.uid), 
                "expires_at": sess.expires_at, 
                "status": "OTP_SENT",
                "provider_response": api_resp
            },
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


from rest_framework import viewsets

class AppUserViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return User.objects.filter(client=user.client).order_by('-created_at')
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            queryset = User.objects.all().order_by('-created_at')
            user_type = self.request.query_params.get('user_type', None)
            if user_type:
                queryset = queryset.filter(user_type=user_type)
            return queryset
        return User.objects.none()

    def get_serializer_class(self):
        if self.action == 'create':
            return AdminCreateUserSerializer
        return AppUserSerializer

    @action(detail=True, methods=['post'], permission_classes=[IsInternalAdmin])
    def request_onboarding(self, request, uid=None):
        user = self.get_object()
        if user.user_type != 'OPERATOR':
            return Response({"detail": "Onboarding can only be requested for operators."}, status=status.HTTP_400_BAD_REQUEST)
        
        # Simulate sending message
        print(f"DEBUG: REQUESTING ONBOARDING for operator {user.username} (Mobile: {user.mobile_primary})")
        # In real world, we would trigger SMS gateway here or create a new OTP session
        
        return Response({"detail": f"Onboarding request sent for {user.username}"})

    @action(detail=False, methods=['post'], permission_classes=[IsInternalAdmin])
    def request_operator(self, request):
        mobile = request.data.get('mobile')
        name = request.data.get('name', '').strip()  # Get name

        if not mobile:
            return Response({"detail": "Mobile number is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        mobile_10 = _normalize_mobile(mobile)
        if not is_valid_indian_mobile(mobile_10):
             return Response({"detail": "Invalid Indian mobile number. Please provide a 10-digit number starting with 6-9."}, status=status.HTTP_400_BAD_REQUEST)

        # Check if already exists
        if User.objects.filter(mobile_primary=mobile_10).exists():
            return Response({"detail": "User with this mobile number already exists."}, status=status.HTTP_400_BAD_REQUEST)

        # Create placeholder user
        try:
            with transaction.atomic():
                username = _generate_operator_username(mobile_10)
                # Ensure username uniqueness (though generator is collision-safe, good to be safe)
                for _ in range(5):
                    if not User.objects.filter(username=username).exists():
                        break
                    username = _generate_operator_username(mobile_10)

                user = User.objects.create_user(
                    username=username,
                    password=None,
                    user_type="OPERATOR",
                    status="REQUESTED",
                    mobile_primary=mobile_10,
                )
                if name:
                    user.first_name = name
                
                user.set_unusable_password()
                # We must include 'full_name' because the model's save() method updates it based on first_name
                user.save(update_fields=["password", "first_name", "full_name"])
                
                # Create profile
                OperatorProfile.objects.get_or_create(user=user)
                
                # Send Onboarding Message
                from .utils import send_onboarding_request_whatsapp
                try:
                    send_onboarding_request_whatsapp(mobile_10, name)
                except Exception as e:
                    print(f"Failed to send WhatsApp to {mobile_10}: {e}")
                
                return Response({
                    "detail": "Operator request created successfully.",
                    "uid": str(user.uid),
                    "username": user.username
                }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['get'], url_path='download-operator-template')
    def download_operator_template(self, request):
        """Generates a CSV template for bulk operator request."""
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="operator_bulk_template.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['mobile', 'name'])
        writer.writerow(['9876543210', 'Rahul Singh'])
        writer.writerow(['8877665544', 'Amit Kumar'])
        
        return response

    @action(detail=False, methods=['post'], permission_classes=[IsInternalAdmin])
    def bulk_request_operator(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
             # Fallback: check manual data
             raw_data = request.data.get('mobiles', [])
             if not raw_data:
                  return Response({"detail": "File or 'mobiles' list required."}, status=status.HTTP_400_BAD_REQUEST)
        
        rows = []
        if file_obj:
             if not file_obj.name.endswith('.csv'):
                return Response({"detail": "Only CSV files are supported."}, status=status.HTTP_400_BAD_REQUEST)
             try:
                file_obj.seek(0)
                decoded_file = file_obj.read().decode('utf-8')
                reader = csv.DictReader(io.StringIO(decoded_file))
                for row in reader:
                    if 'mobile' in row:
                        rows.append( {"mobile": row['mobile'], "name": row.get('name', '')} )
             except Exception as e:
                return Response({"detail": f"Error parsing CSV: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
        else:
            # Manual fallback - handle if they send [{"mobile": "...", "name": "..."}] or just ["..."]
            raw_data = request.data.get('mobiles', [])
            for item in raw_data:
                if isinstance(item, dict):
                    rows.append(item)
                else:
                    rows.append({"mobile": str(item), "name": ""})

        if not rows:
            return Response({"detail": "No valid data found."}, status=status.HTTP_400_BAD_REQUEST)

        results = {
            "created": [],
            "skipped": [],
            "errors": []
        }

        from .utils import send_onboarding_request_whatsapp

        with transaction.atomic():
            for row in rows:
                m = row.get('mobile')
                name = row.get('name', '').strip()

                mobile_10 = _normalize_mobile(str(m))
                if not is_valid_indian_mobile(mobile_10):
                    results["errors"].append({"mobile": m, "reason": "Invalid Indian mobile number."})
                    continue
                
                if User.objects.filter(mobile_primary=mobile_10).exists():
                    results["skipped"].append({"mobile": m, "reason": "User already exists."})
                    continue
                
                try:
                    username = _generate_operator_username(mobile_10)
                    for _ in range(5):
                        if not User.objects.filter(username=username).exists():
                            break
                        username = _generate_operator_username(mobile_10)

                    user = User.objects.create_user(
                        username=username,
                        password=None,
                        user_type="OPERATOR",
                        status="REQUESTED",
                        mobile_primary=mobile_10,
                    )
                    if name:
                        user.first_name = name

                    user.set_unusable_password()
                    # We must include 'full_name' because the model's save() method updates it based on first_name
                    user.save(update_fields=["password", "first_name", "full_name"])
                    
                    OperatorProfile.objects.get_or_create(user=user)
                    
                    # Send WhatsApp
                    try:
                        send_onboarding_request_whatsapp(mobile_10, name)
                    except:
                        pass # Don't fail the batch

                    results["created"].append({"mobile": mobile_10, "username": username})
                except Exception as e:
                    results["errors"].append({"mobile": m, "reason": str(e)})

        return Response(results, status=status.HTTP_200_OK)

class BlacklistTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data["refresh"]
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(status=status.HTTP_205_RESET_CONTENT)
        except Exception:
            return Response(status=status.HTTP_400_BAD_REQUEST)
