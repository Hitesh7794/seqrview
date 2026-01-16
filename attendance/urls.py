from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AttendanceLogViewSet

router = DefaultRouter()
router.register(r'logs', AttendanceLogViewSet, basename='attendance-logs')

urlpatterns = [
    path('', include(router.urls)),
]