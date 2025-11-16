from __future__ import annotations
"""Helpers to interact with LibreView OAuth endpoints.

This module provides two small helpers:
- build_authorize_url(redirect_uri, state): constructs the authorization URL
- exchange_code_for_token(code, redirect_uri): exchanges an authorization
  code for tokens using the configured token endpoint.


- LIBRE_OAUTH_AUTHORIZE_URL
- LIBRE_OAUTH_TOKEN_URL
- LIBRE_OAUTH_CLIENT_ID
- LIBRE_OAUTH_CLIENT_SECRET
- LIBRE_OAUTH_SCOPE (optional)
"""

from urllib.parse import urlencode
import requests
import base64
import os
from django.conf import settings
import hashlib
from typing import Tuple, Optional, Dict
from urllib.parse import urlencode
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


_DEFAULT_TIMEOUT = 15

_SESSION = requests.Session()
_SESSION.mount(
    "https://",
    HTTPAdapter(
        max_retries=Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=[429,500, 502, 503, 504],  
            allowed_methods=["GET", "POST"],
        )
    ),
)

def make_code_verifier() -> str:
    """Generate a secure code verifier for PKCE."""
    return base64.urlsafe_b64encode(os.urandom(40)).rstrip(b'=').decode()

def make_code_challenge(code_verifier: str) -> str:
    """Generate a code challenge from a code verifier for PKCE."""
    digest = hashlib.sha256(code_verifier.encode()).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b'=')  .decode()

def build_authorize_url(redirect_uri: str, state: Optional[str] = None, code_challenge: Optional[str]= None,
code_challenge_method: str ="S256",) -> str:
    base = getattr(settings, 'LIBRE_OAUTH_AUTHORIZE_URL', None)
    client_id = getattr(settings, 'LIBRE_OAUTH_CLIENT_ID', None)
    scope = getattr(settings, 'LIBRE_OAUTH_SCOPE', None)
    if not base or not client_id:
        raise RuntimeError('Libre OAuth not configured (LIBRE_OAUTH_AUTHORIZE_URL or LIBRE_OAUTH_CLIENT_ID missing)')

    params = {
        'response_type': 'code',
        'client_id': client_id,
        'redirect_uri': redirect_uri,
    }
    if scope:
        params['scope'] = scope
    if state:
        params['state'] = state
    if code_challenge :
        params['code_challenge'] = code_challenge
        params['code_challenge_method'] = code_challenge_method
    return base.rstrip("?") + '?' + urlencode(params)


def exchange_code_for_token(code: str, redirect_uri: str, code_verifier: Optional[str]=None, timeout: int = _DEFAULT_TIMEOUT,) -> dict:
    token_url = getattr(settings, 'LIBRE_OAUTH_TOKEN_URL', None)
    client_id = getattr(settings, 'LIBRE_OAUTH_CLIENT_ID', None)
    client_secret = getattr(settings, 'LIBRE_OAUTH_CLIENT_SECRET', None)
    if not token_url or not client_id:
        raise RuntimeError('Libre OAuth token endpoint not configured')

    payload = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect_uri,
        'client_id': client_id,
    }
    if client_secret: 
        payload['client_secret'] = client_secret
    if code_verifier:
        payload['code_verifier'] = code_verifier        


    headers = {'Accept': 'application/json'}
    r = _SESSION.post(token_url, data=payload, headers=headers, timeout=timeout)
    r.raise_for_status()
    return r.json()


def uuid_to_sha256(uuid_str: str) -> str:
    """Return SHA-256 hex digest for a UUID string."""
    return hashlib.sha256(uuid_str.encode('utf-8')).hexdigest()

def _llu_base_url() -> str:
    return getattr(settings, 'LIBRE_PASSWORD_BASE_URL', 'https://api.libreview.io').rstrip("/") 

def _llu_headers_base() -> Dict[str, str]:
    product = getattr(settings, "LIBRE_LLU_PRODUCT", "llu.android") 
    version = getattr(settings, "LIBRE_LLU_VERSION", "4.16.0")
    return {
        "accept-encoding": "gzip",
        "cache-control": "no-cache",
        "connection": "Keep-Alive", 
        "content-type": "application/json",
        "product": product,
        "version": version,
    }

def get_libreview_connection(base_url: str, access_token: str, account_id: str):
    from .libre import _llu_headers_base
    account_id_hashed = hashlib.sha256(account_id.encode()).hexdigest()
    headers = _llu_headers_base()
    headers.update({
        'authorization': f'Bearer {access_token}',
        'account-id': account_id_hashed,    
    })
    resp = requests.request.get(f"{base_url}/llu/connections", headers=headers, timeout= 20)
    resp.raise_for_status()
    return resp.json()



def login_with_password(email: str, password: str, timeout: int = _DEFAULT_TIMEOUT) -> Tuple[Optional[str], Optional[Dict], Optional[Dict]]:
    """Perform LibreView password login flow (non-OAuth).

    Returns a tuple: (base_url, token_response_dict, headers) on success,
    or (None, None, None) on failure.
    """
    base_url = _llu_base_url()
    login_url = f"{base_url}/llu/auth/login"
    headers = _llu_headers_base()
    payload = {'email': email, 'password': password}
  
    try:
        r = _SESSION.post(login_url, headers=headers, json=payload, timeout=timeout)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        return None, None, None

    # Handle region redirect
    try:
        if data.get('data', {}).get('redirect') is True:
            region = data['data'].get('region')
            if region:
                base_url = f"https://api-{region}.libreview.io"
                login_url = f"{base_url}/llu/auth/login"
                r = _SESSION.post(login_url, headers=headers, json=payload, timeout=timeout)
                r.raise_for_status()
                data = r.json()
    except Exception:
         return None, None, None

    # Extract token and user id
    try:
        JWT_token = data['data']['authTicket']['token']
        libre_user_id = data['data']['user']['id']
    except Exception:
        return None, None, None

    account_id_hashed = uuid_to_sha256(libre_user_id)
    auth_headers = {
        **headers,
        'authorization': f'Bearer {JWT_token}',
        'account-id': account_id_hashed,
    }
    

    token_response = {
        'access_token': JWT_token,
        'account_id': libre_user_id,
    }

    return base_url, token_response, auth_headers



