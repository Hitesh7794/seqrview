from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from .models import OperatorAssignment
from .serializers import OperatorAssignmentSerializer

class OperatorAssignmentViewSet(viewsets.ModelViewSet):
    queryset = OperatorAssignment.objects.all()
    serializer_class = OperatorAssignmentSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    @action(detail=False, methods=['get'], url_path='my-duties')
    def my_duties(self, request):
        
        user = request.user
        if getattr(user, 'user_type', '') != 'OPERATOR':
            
             return Response({"error": "Only operators have duties."}, status=status.HTTP_403_FORBIDDEN)
        
        
        assignments = OperatorAssignment.objects.filter(operator=user).order_by('assigned_at')
        serializer = self.get_serializer(assignments, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='confirm')
    def confirm(self, request, uid=None):
        """
        Operator affirms they will attend.
        """
        assignment = self.get_object()
        if assignment.operator != request.user:
            return Response({"error": "Not your assignment"}, status=status.HTTP_403_FORBIDDEN)
            
        if assignment.status != 'PENDING':
             return Response({"error": "Assignment already processed"}, status=status.HTTP_400_BAD_REQUEST)
             
        assignment.status = 'CONFIRMED'
        assignment.confirmed_at = timezone.now()
        assignment.save()
        return Response({"status": "Confirmed", "status_display": "Confirmed"})