from django.test import RequestFactory
from core import views
import traceback

rf = RequestFactory()
req = rf.get('/api/sample-ai/')

try:
    resp = views.sample_ai_view(req)
    print('RESPONSE TYPE:', type(resp))
    print('STATUS:', getattr(resp, 'status_code', None))
    # Some Django HttpResponse objects keep bytes in .content
    print(resp.content.decode('utf-8'))
except Exception:
    traceback.print_exc()
