from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Client, CenterMaster, RoleMaster
from .serializers import ClientSerializer, CenterMasterSerializer, RoleMasterSerializer
from common.permissions import IsInternalAdmin

class ClientViewSet(viewsets.ModelViewSet):
    queryset = Client.objects.all()
    serializer_class = ClientSerializer
    permission_classes = [IsInternalAdmin]

class CenterMasterViewSet(viewsets.ModelViewSet):
    queryset = CenterMaster.objects.all()
    serializer_class = CenterMasterSerializer
    permission_classes = [IsInternalAdmin]

    @action(detail=False, methods=['post'], url_path='bulk-import')
    def bulk_import(self, request):
        # Placeholder for CSV/Excel import
        return Response({"message": "Bulk import not implemented yet"}, status=status.HTTP_501_NOT_IMPLEMENTED)

class RoleMasterViewSet(viewsets.ModelViewSet):
    queryset = RoleMaster.objects.filter(is_active=True)
    serializer_class = RoleMasterSerializer
    permission_classes = [IsInternalAdmin]