from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient


class InsulinAPITests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username='tester', password='pass123')
        if hasattr(self.user, 'insulin_to_carb_ratio'):
            self.user.insulin_to_carb_ratio = 10
        if hasattr(self.user, 'correction_factor'):
            self.user.correction_factor = 50
        self.user.save()
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_insulin_calculate_endpoint(self):
        payload = {
            'total_carbs_g': 60,
            'carb_ratio': 10,
            'current_glucose': 180,
            'correction_factor': 50,
            'iob': 0.0,
        }
        resp = self.client.post('/api/insulin/calculate/', payload, format='json')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('rounded_dose', data)
        self.assertAlmostEqual(data['rounded_dose'], 7.5)

    def test_food_entry_create_saves_insulin(self):
      
        payload = {
            'food_name': 'Test Meal',
            'meal_type': 'lunch',
            'total_carbs_g': 50,
        }
        resp = self.client.post('/api/food-entries/', payload, format='json')
        self.assertIn(resp.status_code, (200, 201), msg=str(getattr(resp, 'json', lambda: resp.content)()))
        data = resp.json()
        
        self.assertIn('insulin_rounded', data)
       
        self.assertAlmostEqual(float(data.get('insulin_rounded') or 0), 5.0)



from unittest.mock import MagicMock, patch
import openai
from django.test import SimpleTestCase
from rest_framework.test import APIClient
from django.core.files.uploadedfile import SimpleUploadedFile


class OpenAIServiceUnitTests(SimpleTestCase):
    def _dummy_image_bytes(self):
        return b"\xFF\xD8\xFF\xE0" + b"0" * 100

    def test_service_happy_path(self):
       
        class FakeChoice:
            def __init__(self, content):
                self.message = type('M', (), {'content': content})

        class FakeResp:
            def __init__(self, content):
                self.choices = [FakeChoice(content)]

        fake_json = '{"name":"burger","components":[{"name":"bun","carbs_g":30}],"total_carbs_g":30.0}'
        fake_client = MagicMock()
        fake_client.chat.completions.create.return_value = FakeResp(fake_json)

        with patch('openai.OpenAI', lambda api_key=None: fake_client):
            from Backend.core.services.openai_service import analyze_image
            out = analyze_image(self._dummy_image_bytes(), user_id=1, request_id='r1')
            self.assertEqual(out['name'], 'burger')


from django.test import TestCase


class OpenAIApiEndpointTests(TestCase):
    def setUp(self):
        User = __import__('django.contrib.auth').contrib.auth.get_user_model()
        self.user = User.objects.create_user(username='tester2', password='pass')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.url = '/api/ai/analyze-image/'

    def _make_file(self, content=b'JPEGDATA', content_type='image/jpeg'):
        return SimpleUploadedFile('img.jpg', content, content_type=content_type)

    def test_no_file_400(self):
        resp = self.client.post(self.url, {})
        self.assertEqual(resp.status_code, 400)

    def test_wrong_type_400(self):
        f = self._make_file(b'data', content_type='application/pdf')
        resp = self.client.post(self.url, {'image': f}, format='multipart')
        self.assertEqual(resp.status_code, 400)

    def test_too_large_400(self):
        big = b'a' * (4 * 1024 * 1024 + 1)
        f = self._make_file(big, content_type='image/jpeg')
        resp = self.client.post(self.url, {'image': f}, format='multipart')
        self.assertEqual(resp.status_code, 400)

    def test_happy_path_calls_service(self):
        with patch('core.api.analyze_image') as mock_analyze:
            mock_analyze.return_value = {'name': 'x', 'components': [], 'total_carbs_g': 0.0}
            f = self._make_file(b'jpeg')
            resp = self.client.post(self.url, {'image': f}, format='multipart')
            self.assertEqual(resp.status_code, 200)

