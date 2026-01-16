from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import OperatorAssignmentViewSet

router = DefaultRouter()
router.register(r'', OperatorAssignmentViewSet) 

urlpatterns = [
    path('', include(router.urls)),
]