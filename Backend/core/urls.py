
from django.contrib import admin
from django.urls import path, include
from rest_framework import routers
from core.services.api import FoodEntryViewSet, GlucoseRecordViewSet
from core.services.api import (
    HealthSyncView, LibreConnectView, LibreWebhookView, InsulinCalculateView,
    LibreOAuthStartView, LibreOAuthCallbackView, LibrePasswordLoginView,
    OpenAIAnalyzeImageView, csrf_token_view, LibreSyncNowView, GlucoseStatisticsView,LibreDisconnectView,LibreConnectionStatusView
)
from core.views import FoodEntryListCreateView, FoodEntryDetailView

router = routers.DefaultRouter()
router.register(r'food-entries', FoodEntryViewSet)
router.register(r'glucose-records', GlucoseRecordViewSet)

urlpatterns = [
   
   
    #core REST routes
    path('', include(router.urls)),
    path('sync/health/', HealthSyncView.as_view(), name='health_sync'),
    path('libre/connect/', LibreConnectView.as_view(), name='libre_connect'),
    path('libre/webhook/', LibreWebhookView.as_view(), name='libre_webhook'),
    path('insulin/calculate/', InsulinCalculateView.as_view(), name='insulin_calculate'),
    path('libre/oauth/start/', LibreOAuthStartView.as_view(), name='libre_oauth_start'),
    path('libre/oauth/callback/', LibreOAuthCallbackView.as_view(), name='libre_oauth_callback'),
    path('libre/login/', LibrePasswordLoginView.as_view(), name='libre_password_login'),
    path('libre/disconnect/', LibreDisconnectView.as_view(), name='libre_disconnect'),
    path('libre/status/', LibreConnectionStatusView.as_view(), name='libre_status'),
    path('ai/analyze-image/', OpenAIAnalyzeImageView.as_view(), name='ai_analyze_image'),
    path('api/csrf/', csrf_token_view, name='csrf_token'),
    path('csrf/' ,csrf_token_view, name='csrf_token'),
    path("libre/sync-now/", LibreSyncNowView.as_view(), name="libre_sync_now"),
    path('glucose-statistics/', GlucoseStatisticsView.as_view(), name='glucose-statistics'),
    path('food/entries/', FoodEntryListCreateView.as_view(), name='food-entry-list-create'),
    path('food/entries/<uuid:pk>/', FoodEntryDetailView.as_view(), name='food-entry-detail'),

]
