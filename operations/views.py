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
    queryset = Exam.objects.all()
    serializer_class = ExamSerializer
    permission_classes = [IsInternalAdmin]

class ShiftViewSet(viewsets.ModelViewSet):
    queryset = Shift.objects.all()
    serializer_class = ShiftSerializer
    permission_classes = [IsInternalAdmin]

class ExamCenterViewSet(viewsets.ModelViewSet):
    queryset = ExamCenter.objects.all()
    serializer_class = ExamCenterSerializer
    permission_classes = [IsInternalAdmin]

class ShiftCenterViewSet(viewsets.ModelViewSet):
    queryset = ShiftCenter.objects.all()
    serializer_class = ShiftCenterSerializer
    permission_classes = [IsInternalAdmin]