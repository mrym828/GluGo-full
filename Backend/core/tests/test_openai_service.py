import pytest
import openai
from unittest.mock import MagicMock, patch

from Backend.core.services.openai_service import analyze_image, OpenAIServiceError, OpenAITimeout, OpenAITooManyRequests


def _dummy_image_bytes():
    return b"\xFF\xD8\xFF\xE0" + b"0" * 100  # small fake jpeg header


def test_analyze_image_happy_path(monkeypatch):
    # Mock OpenAI client response with valid JSON
    class FakeChoice:
        def __init__(self, content):
            self.message = type('M', (), {'content': content})

    class FakeResp:
        def __init__(self, content):
            self.choices = [FakeChoice(content)]

    fake_json = '{"name":"burger","components":[{"name":"bun","carbs_g":30}],"total_carbs_g":30.0}'

    fake_client = MagicMock()
    fake_client.chat.completions.create.return_value = FakeResp(fake_json)

    monkeypatch.setattr('openai.OpenAI', lambda api_key=None: fake_client)

    out = analyze_image(_dummy_image_bytes(), user_id=1, request_id='r1')
    assert out['name'] == 'burger'
    assert isinstance(out['components'], list)


def test_analyze_image_invalid_json(monkeypatch):
    # Model returns invalid JSON -> should raise OpenAIServiceError
    class FakeChoice:
        def __init__(self, content):
            self.message = type('M', (), {'content': content})

    class FakeResp:
        def __init__(self, content):
            self.choices = [FakeChoice(content)]

    fake_client = MagicMock()
    fake_client.chat.completions.create.return_value = FakeResp('NOT A JSON')

    monkeypatch.setattr('openai.OpenAI', lambda api_key=None: fake_client)

    with pytest.raises(OpenAIServiceError):
        analyze_image(_dummy_image_bytes(), user_id=1, request_id='r2')


def test_analyze_image_timeout(monkeypatch):
    # Simulate openai timeout
    fake_client = MagicMock()
    def raise_timeout(*args, **kwargs):
        raise openai.error.Timeout('timed out')
    fake_client.chat.completions.create.side_effect = raise_timeout

    monkeypatch.setattr('openai.OpenAI', lambda api_key=None: fake_client)

    with pytest.raises(OpenAITimeout):
        analyze_image(_dummy_image_bytes(), user_id=1, request_id='r3')


def test_analyze_image_rate_limit(monkeypatch):
    # Simulate rate limit error
    fake_client = MagicMock()
    def raise_ratelimit(*args, **kwargs):
        raise openai.error.RateLimitError('rate limit')
    fake_client.chat.completions.create.side_effect = raise_ratelimit

    monkeypatch.setattr('openai.OpenAI', lambda api_key=None: fake_client)

    with pytest.raises(OpenAITooManyRequests):
        analyze_image(_dummy_image_bytes(), user_id=1, request_id='r4')
