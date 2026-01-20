from rest_framework import permissions

class IsInternalAdmin(permissions.BasePermission):
    """
    Allows access only to Internal Admins or Staff users.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (request.user.is_staff or getattr(request.user, 'user_type', '') == 'INTERNAL_ADMIN')
        )

class IsOperator(permissions.BasePermission):
    """
    Allows access only to Operators.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            getattr(request.user, 'user_type', '') == 'OPERATOR'
        )
