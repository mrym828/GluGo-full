from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import RedirectView

urlpatterns = [
    path('', RedirectView.as_view(url='/glugo/v1/', permanent=False)),
    path('admin/', admin.site.urls),
    path("glugo/v1/", include("core.urls")),
    path("glugo/", include("core.urls")),
    
    # JWT authentication endpoints
    path('glugo/v1/auth/', include('users.urls')), 
    path('glugo/v1/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('glugo/v1/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)