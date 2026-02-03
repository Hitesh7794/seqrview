from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Exam, Shift, ExamCenter, ShiftCenter
from .serializers import (
    ExamSerializer, ShiftSerializer, 
    ExamCenterSerializer, ShiftCenterSerializer
)
from common.permissions import IsInternalAdmin

class ExamViewSet(viewsets.ModelViewSet):
    serializer_class = ExamSerializer
    lookup_field = 'exam_code'

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsInternalAdmin()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        print(f"DEBUG: ExamViewSet User: {user} | Type: {user.user_type} | Super: {user.is_superuser}")
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            qs = Exam.objects.filter(client=user.client)
            print(f"DEBUG: ClientAdmin QS Count: {qs.count()}")
            return qs
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            qs = Exam.objects.filter(uid=user.exam.uid)
            print(f"DEBUG: ExamAdmin QS Count: {qs.count()}")
            return qs
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            qs = Exam.objects.all()
            print(f"DEBUG: InternalAdmin QS Count: {qs.count()}")
            return qs
        print("DEBUG: Returning NONE")
        return Exam.objects.none()

class ShiftViewSet(viewsets.ModelViewSet):
    serializer_class = ShiftSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        qs = Shift.objects.all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            return qs.filter(exam=user.exam)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return qs
        return qs.none()

class ExamCenterViewSet(viewsets.ModelViewSet):
    serializer_class = ExamCenterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        qs = ExamCenter.objects.all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            return qs.filter(exam=user.exam)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return qs
        return qs.none()

class ShiftCenterViewSet(viewsets.ModelViewSet):
    serializer_class = ShiftCenterSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'uid'

    def get_queryset(self):
        user = self.request.user
        qs = ShiftCenter.objects.all()
        if user.user_type == 'CLIENT_ADMIN' and user.client:
            return qs.filter(exam__client=user.client)
        elif user.user_type == 'EXAM_ADMIN' and user.exam:
            return qs.filter(exam=user.exam)
        elif user.user_type == 'INTERNAL_ADMIN' or user.is_superuser:
            return qs
        return qs.none()