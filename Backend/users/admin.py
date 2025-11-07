from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal info', {'fields': ('full_name', 'email', 'phone_number')}),
        ('Diabetes', {'fields': ('diabetes_type', 'diagnoses_year', 'insulin_to_carb_ratio', 'correction_factor')}),
        ('Vitals', {'fields': ('age', 'gender', 'weight_kg', 'height_cm')}),
        ('Preferences', {'fields': ('preferred_med', 'preferred_carb_ratio', 'target_glucose_min', 'target_glucose_max')}),
        ('Libre', {'fields': ('libre_registered', 'libre_username')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'password1', 'password2'),
        }),
    )

    list_display = ('username', 'email', 'full_name', 'is_staff')
    search_fields = ('username', 'email', 'full_name')
