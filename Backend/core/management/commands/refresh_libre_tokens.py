from django.core.management.base import BaseCommand
from django.conf import settings
from core.models import LibreConnection
import requests


class Command(BaseCommand):
    help = 'Refresh Libre OAuth tokens for connections (manual/cron). Minimal implementation for demos.'

    def handle(self, *args, **options):
        token_url = getattr(settings, 'LIBRE_OAUTH_TOKEN_URL', None)
        client_id = getattr(settings, 'LIBRE_OAUTH_CLIENT_ID', None)
        client_secret = getattr(settings, 'LIBRE_OAUTH_CLIENT_SECRET', None)

        if not token_url or not client_id or not client_secret:
            self.stdout.write(self.style.ERROR('LIBRE OAuth token settings missing (LIBRE_OAUTH_TOKEN_URL/CLIENT_ID/CLIENT_SECRET).'))
            return

        conns = LibreConnection.objects.filter(connected=True).exclude(refresh_token__isnull=True).exclude(refresh_token__exact='')
        if not conns.exists():
            self.stdout.write('No connections with refresh tokens found.')
            return

        for lc in conns:
            try:
                payload = {
                    'grant_type': 'refresh_token',
                    'refresh_token': lc.refresh_token,
                    'client_id': client_id,
                    'client_secret': client_secret,
                }
                resp = requests.post(token_url, data=payload, timeout=10)
                resp.raise_for_status()
                token_data = resp.json()
                lc.set_token_data(token_data)
                lc.save()
                self.stdout.write(self.style.SUCCESS(f'Refreshed tokens for LibreConnection user_id={lc.user_id}'))
            except Exception as e:
                self.stdout.write(self.style.WARNING(f'Failed to refresh for user_id={lc.user_id}: {e}'))
