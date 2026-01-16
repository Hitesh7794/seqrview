from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ClientViewSet, CenterMasterViewSet, RoleMasterViewSet

router = DefaultRouter()
router.register(r'clients', ClientViewSet)
router.register(r'centers', CenterMasterViewSet)
router.register(r'roles', RoleMasterViewSet)

urlpatterns = [
    path('', include(router.urls)),
]