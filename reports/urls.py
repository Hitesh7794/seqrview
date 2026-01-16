from django.urls import path
from .views import DailySummaryView

urlpatterns = [
    path('summary/', DailySummaryView.as_view(), name='daily-summary'),
]
