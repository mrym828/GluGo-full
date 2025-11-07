from django.test import Client
from django.core.files.uploadedfile import SimpleUploadedFile
import os
import traceback

# When executed via manage.py shell, __file__ may not be set. Use cwd as a reliable project root.
BASE = os.path.abspath(os.getcwd())
# burger.jpg lives one level above the backend- folder in the workspace root
IMAGE_PATH = os.path.abspath(os.path.join(BASE, '..', 'burger.jpg'))

c = Client()

with open(IMAGE_PATH, 'rb') as f:
    uploaded = SimpleUploadedFile('burger.jpg', f.read(), content_type='image/jpeg')

try:
    resp = c.post('/', {'meal_image': uploaded})
    print('RESPONSE TYPE:', type(resp))
    print(resp.content.decode('utf-8'))
except Exception:
    traceback.print_exc()
