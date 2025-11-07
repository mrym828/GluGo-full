from celery import shared_task
import logging
from typing import Dict, Any, List
from .models import GlucoseRecord, LibreConnection
from django.utils.dateparse import parse_datetime
from django.utils import timezone
from django.contrib/auth import get_user_model
from .services.libre import get_libreview_connection

@shared_task
def sync_libre_for_user(user_id: int):
    from django.db import transaction
    User = get_user_model()
    user = User.objects.get(pk=user_id)

    conn = LibreConnection.objects.filter(user=user, token__isnull = False, api_endpoint__isnull=False).first()
    if not conn:
        return {'error':'no connection'}

    payload = get_libreview_connections(conn.api_endpoint, conn.token, conn.account_id)
    data = payload.get('data') or []
    created = 0
    for item in data:
        gm = (item or {}).get("glucoseMeasurements") or {}
        value = gm.get("values") 
        ts_str = gm.get("Timestamp") or gm.get("timestamp")
        if value is None or not ts_str:
            continue
        ts = parse_datetime(ts_str)
        if ts is None:
            continue

        GlucoseRecord.objects.create(
            user=user,
            timestamp=ts,
            glucose_level=value,
            source='libre_webhook',
            trend_arrow= None,
        )
        creates +=1

    return {'created': created}
   