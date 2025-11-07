import os
import sys
import django
import json

# Add project backend directory to path so Django settings (config) can be imported
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
if PROJECT_DIR not in sys.path:
    sys.path.insert(0, PROJECT_DIR)

# Ensure the Django settings module is set
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.test import APIRequestFactory, force_authenticate

# Import the view and the module so we can patch the helper
from Backend.core.services.api import LibrePasswordLoginView
import Backend.core.services.api as core_api_module

# Create or get a user
User = get_user_model()
username = 'a3alshamsi@hotmail.com'
password = 'Ajhs@link150'
user, created = User.objects.get_or_create(username=username, defaults={'email': username})
if created:
    user.set_password(password)
    user.save()
    print('Created user', username)
else:
    # Ensure password is set to known value for the test
    user.set_password(password)
    user.save()
    print('User exists, updated password for', username)

# Generate JWT tokens for the user
refresh = RefreshToken.for_user(user)
access = str(refresh.access_token)
print('\nACCESS TOKEN:')
print(access)

# Patch the login_with_password helper used by the view to avoid real network calls
# core.api imported login_with_password earlier; overwrite it with a fake.

def fake_login_with_password(email, password):
    # Return base_url, token_response, headers
    base_url = 'https://api.libreview.io'
    token_response = {
        'access_token': 'mock_access_token_123',
        'account_id': 'mock_account_1'
    }
    headers = {'Authorization': 'Bearer mock_access_token_123'}
    return base_url, token_response, headers

core_api_module.login_with_password = fake_login_with_password

# Build a POST request to the LibrePasswordLoginView
factory = APIRequestFactory()
request = factory.post('/api/libre/login/', data={}, format='json')
force_authenticate(request, user=user)

view = LibrePasswordLoginView.as_view()
response = view(request)

print('\nLIBRE LOGIN RESPONSE:')
try:
    # DRF Response may have .data
    print('status_code=', response.status_code)
    print(json.dumps(response.data, indent=2))
except Exception:
    print(response)

print('\nDone')
