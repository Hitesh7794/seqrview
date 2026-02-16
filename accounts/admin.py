from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import AppUser


@admin.register(AppUser)
class AppUserAdmin(BaseUserAdmin):
    ordering = ("username",)
    list_display = ("username", "user_type", "status", "is_staff", "is_superuser", "is_active")
    search_fields = ("username", "email", "full_name", "mobile_primary")

    fieldsets = (
        (None, {"fields": ("username", "password")}),
        ("Personal info", {"fields": ("full_name", "first_name", "middle_name", "last_name", "email", "mobile_primary")}),
        ("Business", {"fields": ("user_type", "status", "client", "exam")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Important dates", {"fields": ("last_login",)}),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("username", "password1", "password2", "user_type", "is_staff", "is_superuser"),
        }),
    )
