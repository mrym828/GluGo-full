from celery import shared_task
import logging
import hashlib
import requests
from datetime import datetime
from typing import Dict, Any, List
from .models import GlucoseRecord, LibreConnection
from django.utils.dateparse import parse_datetime
from django.utils import timezone
from django.contrib.auth import get_user_model
from .libre import get_libreview_connections, login_with_password

@shared_task
def sync_libre_for_user(user_id: int):
    from django.db import transaction
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return {"error":"user_not_found"}
    

    conn = LibreConnection.objects.filter(user=user).first()
    if not conn:
        return {'error':'no connection'}
    base_url = None
    token = None
    account_id = None

    if conn and conn.api_endpoint and conn.token and conn.account_id:
        base_url = conn.api_endpoint
        token = conn.token
        account_id = conn.account_id
    else:
        email = getattr(conn, "email", None)
        password = conn.get_password_decrypted() if conn else None
        if not (email and password):
            return {"error": "missing credentials or connection"}
        
        base_url, token_response, auth_headers = login_with_password(email, password)
        if not auth_headers or not token_response:
            return {"error":"libre login failed"}
        token = token_response.get("access_token")
        account_id = token_response.get("account_id")

        LibreConnection.objects.update_or_create(
            user = user,
            defaults = {
                "api_endpoint": base_url,
                "token": token,
                "account_id": account_id,
                "connected": True if token else False,
                "region": (base_url.split("//api")[-1].split(".")[0] if "api-" in base_url else None),

            },
        )
    try:
        try:
            payload = get_libreview_connections(base_url, token, account_id)
        except ImportError:
            headers = {
                 "accept-encoding": "gzip",
                "cache-control": "no-cache",
                "connection": "Keep-Alive",
                "content-type": "application/json",
                "product": "llu.android",
                "version": "4.16.0",
                "authorization": f"Bearer {token}",
                "account-id": hashlib.sha256(account_id.encode()).hexdigest(),
            }
            r = requests.get(f"{base_url}/llu/connections", headers=headers, timeout=20)
            r.raise_for_status()
            payload = r.json()
    except Exception as e:
        return {"error": f"llu_request_failed: {e}"}

    data = payload.get("data") or []
    fetched = 0
    created = 0

    for item in data:
        gm = (item or {}).get("glucoseMeasurement") or {}
        if not gm:
            continue

        value = gm.get("Value")
        trend = gm.get("TrendArrow")
        ts_str = gm.get("Timestamp") or gm.get("timestamp")
        if value is None or not ts_str:
            continue

        fetched += 1

        # parse timestamp
        ts = parse_datetime(ts_str)
        if ts is None:
            try:
                ts = datetime.fromisoformat(ts_str)
            except Exception:
                continue
        from django.utils import timezone as dj_tz
        if dj_tz.is_naive(ts):
            ts = dj_tz.make_aware(ts, timezone=dj_tz.utc)
        try:
            GlucoseRecord.objects.create(
                user=user,
                timestamp=ts,
                glucose_level=value,
                trend_arrow=trend,
                source="libre",
            )
            created += 1
        except Exception:
            continue
        if conn:
            conn.last_synced = timezone.now()
            conn.save(update_fields=["last_synced"])
        

    return {"user_id": user_id, "fetched": fetched, "created": created}


  