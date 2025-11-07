from django.contrib import admin
from .models import (
    NutritionalInfo,
    FoodEntry,
    GlucoseRecord,
    LibreConnection,
    GlucoseMonitor,
    Preferences,
    Alert,
    InsightReport,
    Recommendation,
    Images,
)



@admin.register(NutritionalInfo)
class NutritionalInfoAdmin(admin.ModelAdmin):
    list_display = ('id', 'calories', 'carbs')


@admin.register(FoodEntry)
class FoodEntryAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'food_name', 'timestamp')
    raw_id_fields = ('user',)


@admin.register(GlucoseRecord)
class GlucoseRecordAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'glucose_level', 'timestamp')
    raw_id_fields = ('user',)


@admin.register(LibreConnection)
class LibreConnectionAdmin(admin.ModelAdmin):
    list_display = ('user', 'email', 'connected')
    raw_id_fields = ('user',)


@admin.register(GlucoseMonitor)
class GlucoseMonitorAdmin(admin.ModelAdmin):
    list_display = ('user',)
    raw_id_fields = ('user',)


@admin.register(Preferences)
class PreferencesAdmin(admin.ModelAdmin):
    list_display = ('user', 'notification_enabled')
    raw_id_fields = ('user',)


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'alert_type', 'timestamp')
    raw_id_fields = ('user',)


@admin.register(InsightReport)
class InsightReportAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'avg_glucose')
    raw_id_fields = ('user',)


@admin.register(Recommendation)
class RecommendationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'category', 'timestamp')
    raw_id_fields = ('user',)


@admin.register(Images)
class ImagesAdmin(admin.ModelAdmin):
    list_display = ('id', 'title')

