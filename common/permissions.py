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

class IsExamAdmin(permissions.BasePermission):
    """
    Allows access only to Exam Admins.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            getattr(request.user, 'user_type', '') == 'EXAM_ADMIN'
        )

class IsExamAdminReadOnly(permissions.BasePermission):
    """
    Allows read-only access to Exam Admins.
    Allows full access to Internal Admins.
    """
    def has_permission(self, request, view):
        # Allow internal admins full access
        if request.user and request.user.is_authenticated and (request.user.is_staff or getattr(request.user, 'user_type', '') == 'INTERNAL_ADMIN'):
            return True

        is_exam_admin = bool(
            request.user and
            request.user.is_authenticated and
            getattr(request.user, 'user_type', '') == 'EXAM_ADMIN'
        )
        return is_exam_admin and request.method in permissions.SAFE_METHODS
