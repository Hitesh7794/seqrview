from rest_framework import viewsets, permissions, status, filters
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.pagination import PageNumberPagination

from common.mixins import ExportMixin
from .serializers import OperatorAssignmentSerializer, AssignmentTaskSerializer, OperatorAssignmentCreateSerializer
from .models import OperatorAssignment, AssignmentTask
from operations.models import ShiftCenter
from masters.models import RoleMaster
from django.utils import timezone
from rest_framework.decorators import action
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from django.db import transaction
from django.http import HttpResponse
from accounts.utils import (
    normalize_mobile, 
    is_valid_indian_mobile, 
    generate_operator_username,
    send_onboarding_request_whatsapp,
    send_assignment_notification_whatsapp
)
import csv
import io

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 1000

class OperatorAssignmentViewSet(ExportMixin, viewsets.ModelViewSet):
    queryset = OperatorAssignment.objects.all()
    # serializer_class = OperatorAssignmentSerializer # Removed in favor of get_serializer_class
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'operator_assignment'
    
    pagination_class = StandardResultsSetPagination
    filter_backends = [filters.SearchFilter, DjangoFilterBackend, filters.OrderingFilter]
    search_fields = ['operator__username', 'operator__first_name', 'operator__last_name', 'operator__mobile_primary']
    filterset_fields = ['status', 'assignment_type', 'role']
    ordering_fields = ['assigned_at', 'status']
    ordering = ['-assigned_at']

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return OperatorAssignmentCreateSerializer
        return OperatorAssignmentSerializer

    def get_queryset(self):
        user = self.request.user
        
        if getattr(user, 'user_type', '') == 'OPERATOR':
             return OperatorAssignment.objects.filter(operator=user).select_related('operator', 'role', 'shift_center')
             
        # For Admins (Internal, Exam, Client)
        queryset = OperatorAssignment.objects.select_related('operator', 'role', 'shift_center').all()
        
        if getattr(user, 'user_type', '') == 'EXAM_ADMIN' and user.exam:
            queryset = queryset.filter(shift_center__shift__exam=user.exam)
        elif getattr(user, 'user_type', '') == 'CLIENT_ADMIN' and user.client:
             queryset = queryset.filter(shift_center__shift__exam__client=user.client)
        elif not (user.is_staff or user.is_superuser or getattr(user, 'user_type', '') == 'INTERNAL_ADMIN'):
             # Fallback for unknown types -> return nothing or self
             return OperatorAssignment.objects.none()

        operator_id = self.request.query_params.get('operator', None)
        if operator_id:
            queryset = queryset.filter(operator__uid=operator_id)
        
        shift_center_id = self.request.query_params.get('shift_center', None)
        if shift_center_id:
            queryset = queryset.filter(shift_center__uid=shift_center_id)
            
        return queryset

    @action(detail=False, methods=['get'], url_path='my-duties')
    def my_duties(self, request):
        
        user = request.user
        if getattr(user, 'user_type', '') != 'OPERATOR':
            
             return Response({"error": "Only operators have duties."}, status=status.HTTP_403_FORBIDDEN)
        
        
        assignments = OperatorAssignment.objects.filter(operator=user).order_by('-assigned_at')
        serializer = self.get_serializer(assignments, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], url_path='download_template')
    def download_template(self, request):
        """Generates a CSV template for bulk operator assignment."""
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="operator_assignment_template.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['operator_mobile', 'operator_name', 'role_name', 'is_primary', 'notes'])
        writer.writerow(['9876543210', 'Rahul Singh', 'Invigilator', '1', 'Main Hall duties'])
        return response

    @action(detail=False, methods=['post'], url_path='bulk-import')
    def bulk_import(self, request):
        shift_center_id = request.data.get('shift_center')
        if not shift_center_id:
             return Response({"detail": "Shift Center ID is required."}, status=status.HTTP_400_BAD_REQUEST)
             
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({"detail": "No file provided."}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            shift_center = ShiftCenter.objects.get(uid=shift_center_id)
        except ShiftCenter.DoesNotExist:
            return Response({"detail": "Invalid Shift Center ID."}, status=status.HTTP_404_NOT_FOUND)

        User = get_user_model()
        results = {"created": [], "updated": [], "errors": []}

        try:
            decoded_file = file_obj.read().decode('utf-8')
            reader = csv.DictReader(io.StringIO(decoded_file))
            
            with transaction.atomic():
                for row in reader:
                    # Basic cleaning
                    data = {k: (v.strip() if v else None) for k, v in row.items()}
                    
                    mobile_raw = data.get('operator_mobile')
                    name = data.get('operator_name', '').strip()
                    role_name = data.get('role_name')
                    
                    if not mobile_raw or not role_name:
                         results["errors"].append({"row": row, "error": "Missing mobile or role_name"})
                         continue
                    
                    mobile = normalize_mobile(mobile_raw)
                    if not is_valid_indian_mobile(mobile):
                         results["errors"].append({"row": row, "error": f"Invalid mobile: {mobile_raw}"})
                         continue

                    # 1. Find or Create Operator
                    try:
                        operator = User.objects.filter(mobile_primary=mobile, user_type='OPERATOR').first()
                        
                        if not operator:
                            # Create new user
                            username = generate_operator_username(mobile)
                            # Collisions loop? (Optional but safe)
                            for _ in range(5):
                                if not User.objects.filter(username=username).exists():
                                    break
                                username = generate_operator_username(mobile)
                            
                            operator = User.objects.create_user(
                                username=username,
                                password=None,
                                user_type="OPERATOR",
                                status="REQUESTED", # Or ONBOARDING? Let's use REQUESTED to match bulk invite
                                mobile_primary=mobile,
                                first_name=name
                            )
                            operator.set_unusable_password()
                            operator.save(update_fields=["password", "first_name", "full_name"])
                            
                            # Create Profile
                            from operators.models import OperatorProfile
                            OperatorProfile.objects.get_or_create(user=operator)
                            
                            # Send Onboarding SMS
                            try:
                                send_onboarding_request_whatsapp(mobile, name)
                            except Exception as e:
                                print(f"Onboarding SMS failed for {mobile}: {e}")

                    except Exception as e:
                        results["errors"].append({"row": row, "error": f"User error: {str(e)}"})
                        continue

                    # 2. Find Role
                    try:
                        role = RoleMaster.objects.get(name__iexact=role_name)
                    except RoleMaster.DoesNotExist:
                        results["errors"].append({"row": row, "error": f"Role '{role_name}' not found"})
                        continue
                        
                    # 3. Create/Update Assignment
                    assignment, created = OperatorAssignment.objects.update_or_create(
                        shift_center=shift_center,
                        operator=operator,
                        defaults={
                            'role': role,
                            'assignment_type': 'PRIMARY' if data.get('is_primary') == '1' else 'BUFFER',
                            'remarks': data.get('notes'),
                            'status': 'PENDING' 
                        }
                    )
                    
                    if created:
                        results["created"].append(operator.username) # Use username or name? Username is unique.
                        # Send Assignment Notification
                        try:
                            send_assignment_notification_whatsapp(mobile, role.name)
                        except Exception as e:
                            print(f"Assignment SMS failed for {mobile}: {e}")
                    else:
                        results["updated"].append(operator.username)
                        # Optional: Send SMS on update?
                        # send_assignment_notification_whatsapp(mobile, role.name)

        except Exception as e:
            return Response({"detail": f"CSV Error: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
            
        return Response(results)

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
             
        # Check if Shift is Locked
        if assignment.shift_center.shift.is_locked:
            return Response({"error": "Cannot confirm. The shift time has passed."}, status=status.HTTP_400_BAD_REQUEST)

        assignment.status = 'CONFIRMED'
        assignment.confirmed_at = timezone.now()
        assignment.save()
        return Response({"status": "Confirmed", "status_display": "Confirmed"})

class AssignmentTaskViewSet(viewsets.ModelViewSet):
    queryset = AssignmentTask.objects.all()
    serializer_class = AssignmentTaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    
    def get_queryset(self):
        user = self.request.user
        qs = super().get_queryset()
        
        # Filter by assignment if provided
        assignment_id = self.request.query_params.get('assignment')
        if assignment_id:
            qs = qs.filter(assignment__uid=assignment_id)
            
        if hasattr(user, 'user_type'):
            if user.user_type == 'OPERATOR':
                return qs.filter(assignment__operator=user)
            elif user.user_type == 'EXAM_ADMIN' and user.exam:
                return qs.filter(assignment__shift_center__shift__exam=user.exam)
            elif user.user_type == 'CLIENT_ADMIN' and user.client:
                return qs.filter(assignment__shift_center__shift__exam__client=user.client)
             
        return qs

    @action(detail=True, methods=['post'])
    def complete(self, request, uid=None):
        task = self.get_object()
        from .models import AssignmentTaskEvidence
        
        # Check if Shift is locked OR Operator has checked out
        if task.assignment.shift_center.shift.is_locked:
            return Response(
                {"detail": "Cannot edit task. The shift is already locked."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        if task.assignment.status == 'COMPLETED':
            return Response(
                {"detail": "Cannot edit task. You have already checked out."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Handle Evidence (Multiple)
        if 'attachments' in request.FILES:
            # Clear old evidence if updating
            AssignmentTaskEvidence.objects.filter(task=task).delete()
            
            for f in request.FILES.getlist('attachments'):
                AssignmentTaskEvidence.objects.create(
                    task=task,
                    file=f,
                    media_type='VIDEO' if 'video' in f.content_type else 'PHOTO'
                )
        
        # Backward compatibility (Single)
        elif 'attachment' in request.FILES:
             # Clear old evidence if updating
             AssignmentTaskEvidence.objects.filter(task=task).delete()
             
             AssignmentTaskEvidence.objects.create(
                task=task,
                file=request.FILES['attachment'],
                media_type='VIDEO' if 'video' in request.FILES['attachment'].content_type else 'PHOTO'
            )
        
        if 'response_data' in request.data:
            task.response_data = request.data['response_data']
            
        task.status = 'COMPLETED'
        task.completed_at = timezone.now()
        task.save()
        return Response({'status': 'completed'})
