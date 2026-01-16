from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import IncidentCategoryViewSet, IncidentViewSet

router = DefaultRouter()
router.register(r'categories', IncidentCategoryViewSet, basename='incident-categories')
router.register(r'incidents', IncidentViewSet, basename='incidents')

urlpatterns = [
    path('', include(router.urls)),
]
