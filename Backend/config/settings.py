

from pathlib import Path
import os
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured


BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / '.env')

# OpenAI key (loaded from environment)
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')

# Default model names 
OPENAI_VISION_MODEL = os.environ.get('OPENAI_VISION_MODEL', 'gpt-4o-mini')
OPENAI_TEXT_MODEL = os.environ.get('OPENAI_TEXT_MODEL', 'gpt-4o-mini')
# Generic model name for image->json tasks (production entrypoint)
OPENAI_MODEL = os.environ.get('OPENAI_MODEL', os.getenv('OPENAI_VISION_MODEL', 'gpt-4o-mini'))
# Timeout (seconds) for upstream OpenAI calls
OPENAI_TIMEOUT = int(os.environ.get('OPENAI_TIMEOUT', '20'))

# Optional: single static LibreView account mode. When enabled the server will
# use the static email/password below for any Libre password-login flows.
LIBRE_STATIC_ENABLED = os.environ.get('LIBRE_STATIC_ENABLED', '0') in ('1', 'true', 'True')
LIBRE_STATIC_EMAIL = os.environ.get('LIBRE_STATIC_EMAIL')
LIBRE_STATIC_PASSWORD = os.environ.get('LIBRE_STATIC_PASSWORD')

# Fernet key encrypting LibreConnection.password_encrypted at rest. Distinct
# from SECRET_KEY so it can be rotated independently of session/JWT signing.
# Generate one with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
LIBRE_FIELD_ENCRYPTION_KEY = os.getenv('LIBRE_FIELD_ENCRYPTION_KEY')

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



# SECURITY WARNING: don't run with debug turned on in production!
# Defaults closed (production-safe); local dev sets DEBUG=1 in .env.
DEBUG = os.getenv('DEBUG', '0') not in ('0', 'False', 'false')

# SECURITY WARNING: keep the secret key used in production secret!
# No insecure fallback once DEBUG is off — a prod deploy missing this env
# var should fail to boot, not silently run with a public default key.
SECRET_KEY = os.getenv('SECRET_KEY') or ('django-insecure-development-key' if DEBUG else None)
if not SECRET_KEY:
    raise ImproperlyConfigured('SECRET_KEY environment variable must be set when DEBUG=0')


def _env_list(name, default):
    raw = os.getenv(name)
    return [v.strip() for v in raw.split(',') if v.strip()] if raw else default


ALLOWED_HOSTS = _env_list('ALLOWED_HOSTS', ['*'] if DEBUG else [])


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
    'whitenoise.middleware.WhiteNoiseMiddleware',
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
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'glugo'),
        'USER': os.getenv('DB_USER', 'glugo'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'glugo_dev'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
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
STATIC_ROOT = BASE_DIR / 'staticfiles'  # collectstatic output, served by WhiteNoise
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedStaticFilesStorage",
    },
}

# Default primary key field type

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Cookies only go out over HTTPS once we're actually running in production.
CSRF_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_HTTPONLY = False
CSRF_COOKIE_SAMESITE = 'Lax'
CSRF_TRUSTED_ORIGINS = _env_list('CSRF_TRUSTED_ORIGINS', ['http://127.0.0.1:8000'] if DEBUG else [])

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    # Set when behind a TLS-terminating reverse proxy/load balancer (nginx,
    # Heroku, etc.) — without it Django can't tell the original request was
    # HTTPS and SECURE_SSL_REDIRECT above will redirect-loop.
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

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

CORS_ALLOWED_ORIGINS = _env_list('CORS_ALLOWED_ORIGINS', [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://192.168.0.105:8000",
    "http://10.255.2.248:8000",
] if DEBUG else [])

# Wide-open only in dev. CORS_ALLOW_ALL_ORIGINS=True combined with
# CORS_ALLOW_CREDENTIALS=True makes django-cors-headers echo back whatever
# Origin the browser sent instead of enforcing CORS_ALLOWED_ORIGINS above —
# fine for local development, not for production.
CORS_ALLOW_ALL_ORIGINS = DEBUG

CORS_ALLOW_CREDENTIALS = True

# Logging — plain stdout, one line per record. Deliberately not writing to a
# local file: this app runs under Docker/whatever process manager sits in
# front of it, and those already capture stdout, so a file here would just
# be a second, easier-to-forget copy to rotate and ship.
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{asctime} {levelname} {name}: {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
        'core': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'DEBUG' if DEBUG else 'INFO'),
            'propagate': False,
        },
        'users': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'DEBUG' if DEBUG else 'INFO'),
            'propagate': False,
        },
    },
}

# Error monitoring — opt-in. Does nothing until SENTRY_DSN is actually set,
# so this is inert for local dev and for anyone who hasn't set up a Sentry
# project yet. send_default_pii is explicitly off: this app handles glucose
# and insulin data, so error reports shouldn't silently start including
# request bodies/user identifiers unless that's a deliberate later decision.
SENTRY_DSN = os.getenv('SENTRY_DSN')
if SENTRY_DSN:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[DjangoIntegration()],
        environment=os.getenv('SENTRY_ENVIRONMENT', 'development' if DEBUG else 'production'),
        traces_sample_rate=float(os.getenv('SENTRY_TRACES_SAMPLE_RATE', '0.0')),
        send_default_pii=False,
    )