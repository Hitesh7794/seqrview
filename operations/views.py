from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterTask
from .serializers import (
    ExamSerializer, ShiftSerializer, 
    ExamCenterSerializer, ShiftCenterSerializer,
    ShiftCenterTaskSerializer
)
from common.permissions import IsInternalAdmin
import csv
import io
from django.http import HttpResponse
from django.db import transaction

from common.mixins import ExportMixin

class ExamViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ExamSerializer
    lookup_field = 'uid'
    basename = 'exam'

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsInternalAdmin()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        print(f"DEBUG: ExamViewSet User: {user} | Type: {user.user_type} | Super: {user.is_superuser}")
        
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
            
        return qs

class ShiftViewSet(ExportMixin, viewsets.ModelViewSet):
    serializer_class = ShiftSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'
    basename = 'shift'

    def get_queryset(self):
        user = self.request.user
        qs = Shift.objects.all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = qs.filter(exam=user.exam)
        
        # Apply filters
        exam_id = self.request.query_params.get('exam')
        if exam_id:
            qs = qs.filter(exam__uid=exam_id)
            
        return qs

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

    def get_queryset(self):
        user = self.request.user
        qs = ShiftCenter.objects.all()
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
            'client_center_code', 'client_center_name', 
            'city', 'active_capacity', 'address', 
            'latitude', 'longitude', 'incharge_name', 'incharge_phone'
        ])
        writer.writerow([
            'EX-001', 'Sample School Center', 
            'New Delhi', '200', '123 Test Lane', 
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
                    
                    if not data.get('client_center_code'):
                         results["errors"].append({"row": row, "errors": "Missing client_center_code"})
                         continue

                    # 1. Get/Create ExamCenter (This triggers MasterCenter auto-link)
                    exam_center, created = ExamCenter.objects.get_or_create(
                        exam=shift.exam,
                        client_center_code=data['client_center_code'],
                        defaults={
                            'client_center_name': data.get('client_center_name', data['client_center_code']),
                            'active_capacity': data.get('active_capacity'),
                            'latitude': data.get('latitude'),
                            'longitude': data.get('longitude'),
                            'incharge_name': data.get('incharge_name'),
                            'incharge_phone': data.get('incharge_phone'),
                            'client_specific_instructions': data.get('address') # Storing address as instruction for now or we map it if field exists
                        }
                    )
                    
                    # 2. Link to Shift
                    shift_center, sc_created = ShiftCenter.objects.get_or_create(
                        exam=shift.exam,
                        shift=shift,
                        exam_center=exam_center
                    )
                    
                    results["created"].append({
                        "center_code": data['client_center_code'],
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
                
                # Update details if provided and center already exists (optional, but good for corrections)
                if not created: 
                    updated = False
                    for field in ['client_center_name', 'active_capacity', 'latitude', 'longitude', 'incharge_name', 'incharge_phone', 'city']:
                        if request.data.get(field):
                             setattr(exam_center, field, request.data.get(field))
                             updated = True
                    if request.data.get('address'):
                        exam_center.client_specific_instructions = request.data.get('address')
                        updated = True
                    
                    if updated:
                        exam_center.save()


                # 2. Link to Shift
                shift_center, sc_created = ShiftCenter.objects.get_or_create(
                    exam=shift.exam,
                    shift=shift,
                    exam_center=exam_center
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
