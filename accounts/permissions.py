from rest_framework.permissions import BasePermission


class IsInternalAdmin(BasePermission):
    
    def has_permission(self, request, view):
        u = request.user
        return bool(
            u and u.is_authenticated and (
                getattr(u, "is_superuser", False) is True or getattr(u, "user_type", "") == "INTERNAL_ADMIN"
            )
        )
