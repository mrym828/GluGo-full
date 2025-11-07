import hashlib
import json
import logging
import time
from typing import List, Optional

from django.conf import settings
import base64
from PIL import Image
from io import BytesIO
import openai
from openai import OpenAI
_USE_NEW_SDK = True


from pydantic import BaseModel, ValidationError    

logger = logging.getLogger(__name__)


class Component(BaseModel):
    name: str
    carbs_g: float


class OpenAIImageResponse(BaseModel):
    name: str
    components: List[Component]
    total_carbs_g: float
    confidence: Optional[float] = None
    calories_estimate: Optional[float] = None

#custom exceptions for OpenAI service errors
class OpenAIServiceError(Exception):
    status = 502


class OpenAITimeout(OpenAIServiceError):
    status = 504


class OpenAITooManyRequests(OpenAIServiceError):
    status = 429

#helpers
def _hash_user_id(user_id: Optional[int]) -> str:
    if user_id is None:
        return 'anon'
    return hashlib.sha256(str(user_id).encode()).hexdigest()[:16]


def _strip_exif(image_bytes: bytes) -> bytes:
    # Remove EXIF by re-saving the image without info
    try:
        img = Image.open(BytesIO(image_bytes))
        # Convert to RGB to avoid problems with palettes
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        out = BytesIO()
        img.save(out, format='JPEG', quality=85)
        return out.getvalue()
    except Exception:
        # If pillow fails, just return original bytes
        return image_bytes

#make entrypoint
def analyze_image(image_bytes: bytes, user_id: Optional[int] = None, request_id: Optional[str] = None) -> dict:
    """Call OpenAI to analyze an image and return validated JSON matching OpenAIImageResponse.

    """
    start = time.time()
    hashed_user = _hash_user_id(user_id)
    rid = request_id or 'rid-none'

    # Sanitize image (strip EXIF/GPS)
    safe_image = _strip_exif(image_bytes)
    base64_image = base64.b64encode(safe_image).decode('utf-8')

    model = getattr(settings, 'OPENAI_VISION_MODEL', None) or getattr(settings, 'OPENAI_MODEL', None)
    if not model:
        raise OpenAIServiceError("missing OPENAI_VISION_MODEL in settings")
    timeout = getattr(settings, 'OPENAI_TIMEOUT', 20)

    client = OpenAI(api_key=settings.OPENAI_API_KEY)
    request_kwargs = {'timeout': timeout}

    # System instruction requesting strict JSON onl

    system_instruction = (
        "You are a food nutrition assistant.\n"
        "Given an image, identify the main dish and its individual components. "
        "For each component, estimate carbohydrates in grams. "
        "Return ONLY a single valid JSON object:\n"
        "{\n"
        '  "name": string,\n'
        '  "components": [ { "name": string, "carbs_g": number } ],\n'
        '  "total_carbs_g": number,\n'
        '  "confidence": number (0-1, optional),\n'
        '  "calories_estimate": number (optional)\n'
        "}\n"
        "All numbers must be plain numbers (not strings). Use grams for carbs."
    )

    user_message_text = (
        "Analyze this meal image and estimate carbs per component, then compute total_carbs_g as the sum."

    )

    user_content = [
        {"type": "text", "text": user_message_text},
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}},
    ]

    max_retries = 2
    attempt = 0
    last_exc = None

    while attempt <= max_retries:
        attempt += 1
        try:
            # send as a small multipart-like payload
            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_instruction},
                    {"role": "user", "content": user_content},
                ],
                max_tokens=800,
                temperature=0,
                **request_kwargs,
            )
               
           
            raw_text = resp.choices[0].message.content
            start_br = raw_text.find("{")
            end_br = raw_text.rfind("}")
            json_text = raw_text[start_br:end_br+1] if (start_br != -1 and end_br != -1 and end_br > start_br) else raw_text


            parsed = json.loads(json_text)

            # Validate with pydantic
            validated = OpenAIImageResponse.parse_obj(parsed)

            duration = time.time() - start
            logger.info("openai_success user=%s request_id=%s latency=%.3f", hashed_user, rid, duration)
            return validated.dict()

        except ValidationError as ve:
            logger.warning("openai_invalid_json user=%s request_id=%s error=%s", hashed_user, rid, ve)
            # upstream returned JSON but it didn't match schema
            raise OpenAIServiceError("model_returned_invalid_json")
        except Exception as exc:
            last_exc = exc
            msg = str(exc).lower()
            if "rate limit" in msg or "429" in msg:
                logger.warning("openai_rate_limited user=%s request_id=%s attempt=%d", hashed_user, rid, attempt)
                if attempt > max_retries:
                    raise OpenAITooManyRequests("rate_limited")
                time.sleep(1)
                continue
            if "timeout" in msg or "timed out" in msg:
                logger.warning("openai_timeout user=%s request_id=%s", hashed_user, rid)
                raise OpenAITimeout("timeout")
            if attempt <= max_retries:
                logger.warning("openai_api_error user=%s request_id=%s attempt=%d error=%s", hashed_user, rid, attempt, str(exc))
                time.sleep(1)
                continue
            logger.exception("openai_unexpected_final user=%s request_id=%s", hashed_user, rid)
            raise OpenAIServiceError("unexpected_error")
    raise OpenAIServiceError(str(last_exc) if last_exc else "unknown_error")
            
            
        

  
