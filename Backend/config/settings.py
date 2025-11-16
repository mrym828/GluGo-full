

from pathlib import Path
import os
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / '.env')

# OpenAI key (loaded from environment)
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')

# Default model names 
OPENAI_VISION_MODEL = os.environ.get('OPENAI_VISION_MODEL', 'gpt-4o-mini-vision')
OPENAI_TEXT_MODEL = os.environ.get('OPENAI_TEXT_MODEL', 'gpt-4o-mini')
# Generic model name for image->json tasks (production entrypoint)
OPENAI_MODEL = os.environ.get('OPENAI_MODEL', os.getenv('OPENAI_VISION_MODEL', 'gpt-4o-mini-vision'))
# Timeout (seconds) for upstream OpenAI calls
OPENAI_TIMEOUT = int(os.environ.get('OPENAI_TIMEOUT', '20'))

# Optional: single static LibreView account mode. When enabled the server will
# use the static email/password below for any Libre password-login flows.
LIBRE_STATIC_ENABLED = os.environ.get('LIBRE_STATIC_ENABLED', '0') in ('1', 'true', 'True')
LIBRE_STATIC_EMAIL = os.environ.get('LIBRE_STATIC_EMAIL')
LIBRE_STATIC_PASSWORD = os.environ.get('LIBRE_STATIC_PASSWORD')

LIBRE_OAUTH_CLIENT_ID = os.getenv('LIBRE_OAUTH_CLIENT_ID', '')
LIBRE_OAUTH_CLIENT_SECRET = os.getenv('LIBRE_OAUTH_CLIENT_SECRET', '')  
LIBRE_OAUTH_AUTHORIZE_URL = 'https://api.libreview.io/oauth/authorize'  
LIBRE_OAUTH_TOKEN_URL = 'https://api.libreview.io/oauth/token'  
LIBRE_OAUTH_SCOPE = 'read:glucose read:connections'  

LIBRE_PASSWORD_BASE_URL = 'https://api.libreview.io'
LIBRE_LLU_PRODUCT = 'llu.android'
LIBRE_LLU_VERSION = '4.16.0'

#celery settings
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', 'redis://127.0.0.1:6379/0')
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'redis://127.0.0.1:6379/1')

CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'

CELERY_ENABLE_UTC = True



# Quick-start development settings - unsuitable for production


# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('SECRET_KEY', 'django-insecure-development-key')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.getenv('DEBUG', '1') not in ('0', 'False', 'false')

ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '10.0.2.2']


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    #internal apps
    'core.apps.CoreConfig',
    'users.apps.UsersConfig',
    # Django REST Framework for API endpoints
    'rest_framework',
    'rest_framework_simplejwt.token_blacklist',  # Optional
    'django_celery_results',
    'django_celery_beat',
    'corsheaders',
]

# Use custom user model in users app
AUTH_USER_MODEL = 'users.User'

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'


# Database


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


# Password validation


AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)

STATIC_URL = 'static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
CSRF_COOKIE_SECURE =False
#CSRF_ALLOW_CREDENTIALS = False
CSRF_COOKIE_HTTPONLY =False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SAMESITE = 'Lax'
CSRF_TRUSTED_ORIGINS = ['http://127.0.0.1:8000']
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    # Basic per-user throttling defaults; individual views can override
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.UserRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'user': '1000/day',
        'ai_image': '10/min',
    },
}

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]

CORS_ALLOW_ALL_ORIGINS = True  # Only for development

CORS_ALLOW_CREDENTIALS = True