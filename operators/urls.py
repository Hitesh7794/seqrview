from django.urls import path
from .views import MyOperatorProfileView

urlpatterns = [
    path("profile/", MyOperatorProfileView.as_view()),
]
