from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Client, CenterMaster, RoleMaster
from .serializers import ClientSerializer, CenterMasterSerializer, RoleMasterSerializer
from common.permissions import IsInternalAdmin

from django.db import transaction
from django.contrib.auth import get_user_model
from rest_framework.response import Response
from rest_framework import status
import secrets
import string

User = get_user_model()

class ClientViewSet(viewsets.ModelViewSet):
    serializer_class = ClientSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return Client.objects.filter(uid=user.client.uid)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return Client.objects.all()
        return Client.objects.none()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        with transaction.atomic():
            client = serializer.save()
            
            # Auto-create Client Admin User
            username = f"{client.client_code.lower()}_admin"
            password = ''.join(secrets.choice(string.ascii_letters + string.digits) for i in range(10))
            
            client.admin_username = username
            client.admin_password = password
            client.save()
            
            user = User.objects.create_user(
                username=username,
                password=password,
                user_type="CLIENT_ADMIN",
                client=client,
                email=client.primary_contact_email,
                full_name=client.name
            )

        headers = self.get_success_headers(serializer.data)
        data = serializer.data
        # Inject credentials into response for display
        data['generated_credentials'] = {
            'username': username,
            'password': password
        }
        return Response(data, status=status.HTTP_201_CREATED, headers=headers)

class CenterMasterViewSet(viewsets.ModelViewSet):
    serializer_class = CenterMasterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return CenterMaster.objects.filter(client=user.client)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return CenterMaster.objects.all()
        return CenterMaster.objects.none()

    @action(detail=False, methods=['post'], url_path='bulk-import')
    def bulk_import(self, request):
        # Placeholder for CSV/Excel import
        return Response({"message": "Bulk import not implemented yet"}, status=status.HTTP_501_NOT_IMPLEMENTED)

class RoleMasterViewSet(viewsets.ModelViewSet):
    serializer_class = RoleMasterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        return RoleMaster.objects.filter(is_active=True)