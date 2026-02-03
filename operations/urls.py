from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ExamViewSet, ShiftViewSet, ExamCenterViewSet, ShiftCenterViewSet

router = DefaultRouter()
router.register(r'exams', ExamViewSet, basename='exam')
router.register(r'shifts', ShiftViewSet, basename='shift')
router.register(r'exam-centers', ExamCenterViewSet, basename='examcenter')
router.register(r'shift-centers', ShiftCenterViewSet, basename='shiftcenter')

urlpatterns = [
    path('', include(router.urls)),
]