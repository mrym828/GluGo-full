from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase
from django.urls import reverse
from unittest.mock import patch


User = get_user_model()


class OpenAIApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='tester', password='pass')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.url = reverse('ai_analyze_image')

    def _make_file(self, content=b'JPEGDATA', content_type='image/jpeg'):
        from django.core.files.uploadedfile import SimpleUploadedFile
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

    @patch('core.api.analyze_image')
    def test_happy_path_calls_service(self, mock_analyze):
        mock_analyze.return_value = {'name': 'x', 'components': [], 'total_carbs_g': 0.0}
        f = self._make_file(b'jpeg')
        resp = self.client.post(self.url, {'image': f}, format='multipart')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('name', resp.json())
