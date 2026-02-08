from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ClientViewSet, CenterMasterViewSet, RoleMasterViewSet, TaskLibraryViewSet

router = DefaultRouter()
router.register(r'clients', ClientViewSet, basename='client')
router.register(r'centers', CenterMasterViewSet, basename='center')
router.register(r'roles', RoleMasterViewSet, basename='role')
router.register(r'task-library', TaskLibraryViewSet, basename='task-library')

urlpatterns = [
    path('', include(router.urls)),
]