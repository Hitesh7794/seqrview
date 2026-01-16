from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Exam, Shift, ExamCenter, ShiftCenter
from .serializers import (
    ExamSerializer, ShiftSerializer, 
    ExamCenterSerializer, ShiftCenterSerializer
)

class ExamViewSet(viewsets.ModelViewSet):
    queryset = Exam.objects.all()
    serializer_class = ExamSerializer
    permission_classes = [permissions.IsAuthenticated]

class ShiftViewSet(viewsets.ModelViewSet):
    queryset = Shift.objects.all()
    serializer_class = ShiftSerializer
    permission_classes = [permissions.IsAuthenticated]

class ExamCenterViewSet(viewsets.ModelViewSet):
    queryset = ExamCenter.objects.all()
    serializer_class = ExamCenterSerializer
    permission_classes = [permissions.IsAuthenticated]

class ShiftCenterViewSet(viewsets.ModelViewSet):
    queryset = ShiftCenter.objects.all()
    serializer_class = ShiftCenterSerializer
    permission_classes = [permissions.IsAuthenticated]