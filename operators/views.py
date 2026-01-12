from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .models import OperatorProfile
from .serializers import OperatorProfileSerializer


class MyOperatorProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Not an operator"}, status=status.HTTP_403_FORBIDDEN)

        profile = request.user.operator_profile
        return Response(OperatorProfileSerializer(profile).data)

    def patch(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Not an operator"}, status=status.HTTP_403_FORBIDDEN)

        profile = request.user.operator_profile
        ser = OperatorProfileSerializer(profile, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()

        if profile.date_of_birth and profile.gender:
            if profile.profile_status == "DRAFT":
                profile.profile_status = "PROFILE_FILLED"
                profile.save(update_fields=["profile_status", "updated_at"])

        return Response(OperatorProfileSerializer(profile).data)
