from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ClientViewSet, CenterMasterViewSet, RoleMasterViewSet

router = DefaultRouter()
router.register(r'clients', ClientViewSet, basename='client')
router.register(r'centers', CenterMasterViewSet, basename='center')
router.register(r'roles', RoleMasterViewSet, basename='role')

urlpatterns = [
    path('', include(router.urls)),
]