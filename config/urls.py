from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from accounts.views import BlacklistTokenView, MeView

def health(_request):
    return JsonResponse({"ok": True})

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", health),

    # Auth
    path("api/auth/token/", TokenObtainPairView.as_view()),
    path("api/auth/token/refresh/", TokenRefreshView.as_view()),
    path("api/auth/logout/", BlacklistTokenView.as_view()),
    path("api/auth/me/", MeView.as_view()),

    # "service-like" routes
    path("api/identity/", include("accounts.urls")),
    path("api/operators/", include("operators.urls")),
    path("api/kyc/", include("kyc.urls")),


    path("api/",include("masters.urls")),
    path("api/operations/", include("operations.urls")),
    path("api/assignments/", include("assignments.urls")),


    path("api/attendance/", include("attendance.urls")),
    path("api/support/", include("support.urls")),
    path("api/reports/", include("reports.urls")),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
