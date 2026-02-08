from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Client, CenterMaster, RoleMaster, TaskLibrary
from .serializers import ClientSerializer, CenterMasterSerializer, RoleMasterSerializer, TaskLibrarySerializer
from common.permissions import IsInternalAdmin
import csv
import io
from django.http import HttpResponse

from django.db import transaction
from django.contrib.auth import get_user_model
from rest_framework.response import Response
from rest_framework import status
import secrets
import string

User = get_user_model()

from common.mixins import ExportMixin

class ClientViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ClientSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'client'

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

class CenterMasterViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = CenterMasterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'center_master'

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return CenterMaster.objects.filter(client=user.client)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return CenterMaster.objects.all()
        return CenterMaster.objects.none()

    @action(detail=False, methods=['get'], url_path='download-template')
    def download_template(self, request):
        """Generates a CSV template for bulk center import."""
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="center_bulk_template.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'name', 'center_code', 'max_candidates_overall', 
            'address', 'city', 'state', 'pincode', 'latitude', 'longitude'
        ])
        # Add a sample row
        writer.writerow([
            'Sample Center', 'C001', '100', 
            '123 Street Name', 'Lucknow', 'Uttar Pradesh', '226001', '26.8467', '80.9462'
        ])
        
        return response

    @action(detail=False, methods=['post'], url_path='bulk-import')
    def bulk_import(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({"detail": "No file provided."}, status=status.HTTP_400_BAD_REQUEST)
        
        if not file_obj.name.endswith('.csv'):
            return Response({"detail": "Only CSV files are supported for now. Please save your Excel file as CSV."}, status=status.HTTP_400_BAD_REQUEST)

        results = {
            "created": [],
            "errors": []
        }

        try:
            decoded_file = file_obj.read().decode('utf-8')
            reader = csv.DictReader(io.StringIO(decoded_file))
            
            with transaction.atomic():
                for row in reader:
                    # Clean data: convert empty strings to None where applicable or handle types
                    cleaned_data = {k: (v.strip() if v else None) for k, v in row.items()}
                    
                    client_id = request.data.get('client_id')
                    client_found = None
                    if client_id:
                        client_found = Client.objects.filter(uid=client_id).first()
                    
                    serializer = self.get_serializer(data=cleaned_data)
                    if serializer.is_valid():
                        serializer.save(client=client_found)
                        results["created"].append(serializer.data)
                    else:
                        results["errors"].append({
                            "row": row,
                            "errors": serializer.errors
                        })
        except Exception as e:
            return Response({"detail": f"Error parsing CSV: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
        
        return Response(results, status=status.HTTP_200_OK if not results["errors"] else status.HTTP_207_MULTI_STATUS)

class RoleMasterViewSet(viewsets.ModelViewSet):
    serializer_class = RoleMasterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        return RoleMaster.objects.filter(is_active=True)

class TaskLibraryViewSet(viewsets.ModelViewSet):
    serializer_class = TaskLibrarySerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    queryset = TaskLibrary.objects.all()
