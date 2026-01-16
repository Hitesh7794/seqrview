from rest_framework import viewsets, permissions, parsers, status
from rest_framework.response import Response
from .models import IncidentCategory, Incident
from .serializers import IncidentCategorySerializer, IncidentSerializer

class IncidentCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = IncidentCategory.objects.filter(is_active=True)
    serializer_class = IncidentCategorySerializer
    permission_classes = [permissions.IsAuthenticated]

class IncidentViewSet(viewsets.ModelViewSet):
    serializer_class = IncidentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or user.is_superuser:
            return Incident.objects.all()
        return Incident.objects.filter(assignment__operator=user)
