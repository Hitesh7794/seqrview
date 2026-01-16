from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ExamViewSet, ShiftViewSet, ExamCenterViewSet, ShiftCenterViewSet

router = DefaultRouter()
router.register(r'exams', ExamViewSet)
router.register(r'shifts', ShiftViewSet)
router.register(r'exam-centers', ExamCenterViewSet)
router.register(r'shift-centers', ShiftCenterViewSet)

urlpatterns = [
    path('', include(router.urls)),
]