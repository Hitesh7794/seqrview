from rest_framework import viewsets, permissions, status, filters
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from .models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterTask
from django.db.models import Count
from .serializers import (
    ExamSerializer, ShiftSerializer, 
    ExamCenterSerializer, ShiftCenterSerializer,
    ShiftCenterTaskSerializer
)
from common.permissions import IsInternalAdmin, IsExamAdminReadOnly, IsExamAdmin
import csv
import io
from django.http import HttpResponse, Http404
from django.db import transaction
from django.core.exceptions import ValidationError

from common.mixins import ExportMixin

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 1000

class ExamViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ExamSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    search_fields = ['name', 'exam_code', 'client__name']
    filterset_fields = ['status']
    lookup_field = 'uid'
    basename = 'exam'

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsInternalAdmin()]
        # Allow read-only for Exam Admins
        return [permissions.IsAuthenticated()]

    def get_object(self):
        queryset = self.filter_queryset(self.get_queryset())
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        lookup_value = self.kwargs[lookup_url_kwarg]

        try:
            # Try to lookup by UID (UUID)
            obj = queryset.get(uid=lookup_value)
        except (ValueError, ValidationError, Exam.DoesNotExist):
            # If invalid UUID or not found, try looking up by exam_code
            try:
                obj = queryset.get(exam_code=lookup_value)
            except Exam.DoesNotExist:
                raise Http404

        self.check_object_permissions(self.request, obj)
        return obj

    def get_queryset(self):
        user = self.request.user
        qs = Exam.objects.none()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = Exam.objects.filter(client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = Exam.objects.filter(uid=user.exam.uid)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            qs = Exam.objects.all()
        
        # Apply filters
        client_id = self.request.query_params.get('client')
        if client_id:
            qs = qs.filter(client__uid=client_id)
            
        return qs.order_by('-created_at')  # Ensure consistent ordering for pagination

    @action(detail=True, methods=['get'])
    def statistics(self, request, uid=None):
        exam = self.get_object()
        from django.utils import timezone
        today = timezone.now().date()
        
        # 1. Shifts
        total_shifts = exam.shifts.count()
        shifts_today = exam.shifts.filter(work_date=today).count()
        completed_shifts = exam.shifts.filter(status='COMPLETED').count()
        
        # 2. Centers
        total_centers = exam.exam_centers.count()
        active_centers = exam.exam_centers.filter(status='ACTIVE').count()
        
        # 3. Operators
        from assignments.models import OperatorAssignment
        total_operators = OperatorAssignment.objects.filter(
            shift_center__shift__exam=exam
        ).values('operator').distinct().count()
        
        operators_active_today = OperatorAssignment.objects.filter(
            shift_center__shift__exam=exam,
            shift_center__shift__work_date=today,
            status__in=['CONFIRMED', 'CHECK_IN', 'COMPLETED']
        ).values('operator').distinct().count()

        # 4. Candidates (Aggregated from centers)
        from django.db.models import Sum
        total_candidates = exam.exam_centers.aggregate(total=Sum('expected_candidates'))['total'] or 0

        return Response({
            "shifts": {
                "total": total_shifts,
                "today": shifts_today,
                "completed": completed_shifts
            },
            "centers": {
                "total": total_centers,
                "active": active_centers
            },
            "operators": {
                "total": total_operators,
                "active_today": operators_active_today
            },
            "candidates": {
                "total": total_candidates
            }
        })

class ShiftViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ShiftSerializer
    # Apply read-only permission for Exam Admins
    permission_classes = [permissions.IsAuthenticated, IsExamAdminReadOnly | IsInternalAdmin] 
    lookup_field = 'uid'
    basename = 'shift'

    def get_queryset(self):
        user = self.request.user
        qs = Shift.objects.annotate(centers_count=Count('shift_centers'))
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = qs.filter(exam=user.exam)
        
        # Apply filters
        exam_id = self.request.query_params.get('exam')
        if exam_id:
            qs = qs.filter(exam__uid=exam_id)
            
        return qs

    @action(detail=True, methods=['get'])
    def statistics(self, request, uid=None):
        shift = self.get_object()
        
        # Total Centers
        total_centers = shift.shift_centers.count()
        
        # Operators Assigned (Distinct operators assigned to centers in this shift)
        # We need to import locally to avoid circular dependency if assignments.models imports operations.models
        from assignments.models import OperatorAssignment
        
        operators_assigned = OperatorAssignment.objects.filter(
            shift_center__shift=shift,
            status__in=['CONFIRMED', 'CHECK_IN', 'COMPLETED']
        ).values('operator').distinct().count()
        
        return Response({
            'total_centers': total_centers,
            'operators_assigned': operators_assigned,
            'task_exceptions': 0 # Placeholder for now
        })

    @action(detail=True, methods=['post'], url_path='bulk-tasks')
    def bulk_tasks(self, request, uid=None):
        shift = self.get_object()
        
        # Input Validation
        role_uid = request.data.get('role')
        tasks_raw = request.data.get('tasks', []) # Could be string if FormData
        
        # Handle FormData stringified JSON
        if isinstance(tasks_raw, str):
            import json
            try:
                tasks_data = json.loads(tasks_raw)
            except json.JSONDecodeError:
                return Response({"detail": "Invalid tasks JSON format."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            tasks_data = tasks_raw

        if not role_uid or not tasks_data:
            return Response({"detail": "Role and Tasks are required."}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            from masters.models import RoleMaster
            role = RoleMaster.objects.get(uid=role_uid)
        except RoleMaster.DoesNotExist:
             return Response({"detail": "Invalid Role"}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Determine Scope (All centers vs CSV filtered)
        centers = shift.shift_centers.all()
        file_obj = request.FILES.get('file')
        
        if file_obj:
            try:
                decoded_file = file_obj.read().decode('utf-8')
                reader = csv.DictReader(io.StringIO(decoded_file))
                # Support both center_code and client_center_code
                target_codes = [
                    row.get('center_code', row.get('client_center_code', '')).strip() 
                    for row in reader 
                    if row.get('center_code') or row.get('client_center_code')
                ]
                if target_codes:
                    centers = centers.filter(exam_center__client_center_code__in=target_codes)
                else:
                    return Response({"detail": "CSV must contain a 'center_code' column."}, status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                return Response({"detail": f"Error parsing CSV: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        created_count = 0
        updated_count = 0
        
        from .models import ShiftCenterTask
        
        with transaction.atomic():
            for center in centers:
                for task_def in tasks_data:
                    task_name = task_def.get('task_name', '').strip()
                    if not task_name: continue
                    
                    # Update or Create
                    obj, created = ShiftCenterTask.objects.update_or_create(
                        shift_center=center,
                        role=role,
                        task_name=task_name,
                        defaults={
                            'task_type': task_def.get('task_type', 'CHECKLIST'),
                            'is_mandatory': task_def.get('is_mandatory', True)
                        }
                    )
                    if created:
                        created_count += 1
                    else:
                        updated_count += 1
                        
        return Response({
            "detail": f"Processed {len(centers)} centers.",
            "centers_count": len(centers),
            "tasks_created": created_count,
            "tasks_updated": updated_count
        })

    @action(detail=False, methods=['get'], url_path='bulk-tasks-template')
    def bulk_tasks_template(self, request):
        """Generates a CSV template for selective bulk task config."""
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="bulk_task_scope_template.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['center_code'])
        # Add sample rows
        writer.writerow(['EX-001'])
        writer.writerow(['C102-MUM'])
        
        return response

class ExamCenterViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ExamCenterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'exam_center'

    def get_queryset(self):
        user = self.request.user
        qs = ExamCenter.objects.all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = qs.filter(exam=user.exam)
            
        # Apply filters
        exam_id = self.request.query_params.get('exam')
        if exam_id:
            qs = qs.filter(exam__uid=exam_id)
            
        return qs

class ShiftCenterViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ShiftCenterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'shift_center'

    pagination_class = StandardResultsSetPagination
    filter_backends = [filters.SearchFilter, DjangoFilterBackend, filters.OrderingFilter]
    search_fields = ['exam_center__client_center_name', 'exam_center__client_center_code', 'exam_center__city']
    ordering_fields = ['exam_center__client_center_name', 'created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        qs = ShiftCenter.objects.select_related('exam_center', 'shift').annotate(
            tasks_count=Count('tasks', distinct=True)
        ).all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = qs.filter(exam=user.exam)
            
        # Apply filters
        shift_id = self.request.query_params.get('shift')
        if shift_id:
            qs = qs.filter(shift__uid=shift_id)
            
        return qs

    @action(detail=False, methods=['get'], url_path='download-template')
    def download_template(self, request):
        """Generates a CSV template for bulk shift center assignment."""
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="shift_center_import_template.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'center_code', 'center_name', 
            'city', 'operators_required', 'address', 
            'latitude', 'longitude', 'incharge_name', 'incharge_phone'
        ])
        writer.writerow([
            'EX-001', 'Sample School Center', 
            'New Delhi', '2', '123 Test Lane', 
            '28.6139', '77.2090', 'John Doe', '9876543210'
        ])
        return response

    @action(detail=False, methods=['post'], url_path='bulk-import')
    def bulk_import(self, request):
        shift_id = request.data.get('shift')
        if not shift_id:
            return Response({"detail": "Shift ID is required."}, status=status.HTTP_400_BAD_REQUEST)
            
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({"detail": "No file provided."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            shift = Shift.objects.get(uid=shift_id)
        except Shift.DoesNotExist:
             return Response({"detail": "Invalid Shift ID."}, status=status.HTTP_404_NOT_FOUND)

        results = {"created": [], "errors": []}

        try:
            decoded_file = file_obj.read().decode('utf-8')
            reader = csv.DictReader(io.StringIO(decoded_file))
            
            with transaction.atomic():
                for row in reader:
                    # Basic cleaning
                    data = {k: (v.strip() if v else None) for k, v in row.items()}
                    
                    # Support both center_code and client_center_code
                    center_code = data.get('center_code') or data.get('client_center_code')
                    
                    if not center_code:
                         results["errors"].append({"row": row, "errors": "Missing center_code"})
                         continue

                    # 1. Get/Create ExamCenter (NO global sync here if exists)
                    exam_center, created = ExamCenter.objects.get_or_create(
                        exam=shift.exam,
                        client_center_code=center_code,
                        defaults={
                            'client_center_name': data.get('center_name') or data.get('client_center_name') or center_code,
                            'operators_required': data.get('operators_required') or data.get('active_capacity'),
                            'latitude': data.get('latitude'),
                            'longitude': data.get('longitude'),
                            'incharge_name': data.get('incharge_name'),
                            'incharge_phone': data.get('incharge_phone'),
                            'client_specific_instructions': data.get('address')
                        }
                    )
                    
                    # 2. Link to Shift (Snapshot all metadata here for full isolation)
                    shift_center, sc_created = ShiftCenter.objects.update_or_create(
                        exam=shift.exam,
                        shift=shift,
                        exam_center=exam_center,
                        defaults={
                            'operators_required': data.get('operators_required') or data.get('active_capacity'),
                            'center_name': data.get('center_name') or data.get('client_center_name') or exam_center.client_center_name,
                            'city': data.get('city') or exam_center.city,
                            'address': data.get('address') or exam_center.client_specific_instructions,
                            'latitude': data.get('latitude') or exam_center.latitude,
                            'longitude': data.get('longitude') or exam_center.longitude,
                            'incharge_name': data.get('incharge_name') or exam_center.incharge_name,
                            'incharge_phone': data.get('incharge_phone') or exam_center.incharge_phone,
                        }
                    )
                    
                    results["created"].append({
                        "center_code": center_code,
                        "status": "Linked" if not sc_created else "Created"
                    })

        except Exception as e:
            return Response({"detail": f"CSV Error: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
            
        return Response(results)

    @action(detail=False, methods=['post'], url_path='add-center')
    def add_center(self, request):
        """Adds a single center to the shift by code."""
        shift_id = request.data.get('shift')
        client_center_code = request.data.get('client_center_code')
        
        if not shift_id or not client_center_code:
            return Response({"detail": "Shift ID and Center Code are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            shift = Shift.objects.get(uid=shift_id)
        except Shift.DoesNotExist:
             return Response({"detail": "Invalid Shift ID."}, status=status.HTTP_404_NOT_FOUND)

        try:
            with transaction.atomic():
                # 1. Get/Create ExamCenter
                exam_center, created = ExamCenter.objects.get_or_create(
                    exam=shift.exam,
                    client_center_code=client_center_code,
                    defaults={
                        'client_center_name': request.data.get('client_center_name', client_center_code),
                        'active_capacity': request.data.get('active_capacity'),
                        'latitude': request.data.get('latitude'),
                        'longitude': request.data.get('longitude'),
                        'incharge_name': request.data.get('incharge_name'),
                        'incharge_phone': request.data.get('incharge_phone'),
                        'client_specific_instructions': request.data.get('address'),
                        'city': request.data.get('city')
                    }
                )
                
                # 2. Link to Shift (Snapshot all metadata here for full isolation)
                shift_center, sc_created = ShiftCenter.objects.update_or_create(
                    exam=shift.exam,
                    shift=shift,
                    exam_center=exam_center,
                    defaults={
                        'operators_required': request.data.get('operators_required') or request.data.get('active_capacity'),
                        'center_name': request.data.get('center_name') or request.data.get('client_center_name') or exam_center.client_center_name,
                        'city': request.data.get('city') or exam_center.city,
                        'address': request.data.get('address') or exam_center.client_specific_instructions,
                        'latitude': request.data.get('latitude') or exam_center.latitude,
                        'longitude': request.data.get('longitude') or exam_center.longitude,
                        'incharge_name': request.data.get('incharge_name') or exam_center.incharge_name,
                        'incharge_phone': request.data.get('incharge_phone') or exam_center.incharge_phone,
                    }
                )
                
                return Response({
                    "detail": "Center added successfully" if sc_created else "Center already linked",
                    "data": ShiftCenterSerializer(shift_center).data
                })

        except Exception as e:
             return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class ShiftCenterTaskViewSet(viewsets.ModelViewSet):
    serializer_class = ShiftCenterTaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    queryset = ShiftCenterTask.objects.all()

    def get_queryset(self):
        qs = super().get_queryset()
        shift_center_id = self.request.query_params.get('shift_center')
        if shift_center_id:
            qs = qs.filter(shift_center__uid=shift_center_id)
        return qs

    def destroy(self, request, *args, **kwargs):
        try:
            return super().destroy(request, *args, **kwargs)
        except Exception as e:
            return Response(
                {"detail": f"Cannot delete task: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )
