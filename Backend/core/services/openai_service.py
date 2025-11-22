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

logger = logging.getLogger(__name__)

from pydantic import BaseModel, ValidationError    


class Component(BaseModel):
    name: str
    carbs_g: float


class OpenAIImageResponse(BaseModel):
    name: str
    components: List[Component]
    total_carbs_g: float
    confidence: Optional[float] = None
    calories_estimate: Optional[float] = None
    total_protein_g: float
    total_fat_g: float


# Custom exceptions for OpenAI service errors
class OpenAIServiceError(Exception):
    status = 502


class OpenAITimeout(OpenAIServiceError):
    status = 504


class OpenAITooManyRequests(OpenAIServiceError):
    status = 429


# Helpers
def _hash_user_id(user_id: Optional[int]) -> str:
    if user_id is None:
        return 'anon'
    return hashlib.sha256(str(user_id).encode()).hexdigest()[:16]


def _process_and_encode_image(image_bytes: bytes) -> tuple[str, str]:
    """
    Process image: remove EXIF, ensure proper format, and encode to base64.
    Returns (base64_string, image_format)
    """
    try:
        # Open image with PIL
        try:
            img = Image.open(BytesIO(image_bytes))
        except Exception as e:
            # Try to open with a common format hint if initial open fails
            try:
                img = Image.open(BytesIO(image_bytes), formats=['JPEG', 'PNG'])
            except Exception:
                raise e # Re-raise original exception if hint fails
        
        # Get original format
        original_format = img.format or 'JPEG'
        
        # Convert to RGB if needed (handles RGBA, P, etc.)
        if img.mode in ("RGBA", "LA", "P", "PA"):
            # Create white background for transparency
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == "P":
                img = img.convert("RGBA")
            background.paste(img, mask=img.split()[-1] if img.mode in ("RGBA", "LA", "PA") else None)
            img = background
        elif img.mode != "RGB":
            img = img.convert("RGB")
        
        # Resize if image is too large (OpenAI has limits)
        max_size = 2048
        if max(img.size) > max_size:
            ratio = max_size / max(img.size)
            new_size = tuple(int(dim * ratio) for dim in img.size)
            img = img.resize(new_size, Image.Resampling.LANCZOS)
            logger.info(f"Resized image from {image_bytes.__sizeof__()} to {new_size}")
        
        # Save to BytesIO without EXIF
        output = BytesIO()
        img.save(output, format='JPEG', quality=90, optimize=True)
        processed_bytes = output.getvalue()
        
        # Encode to base64
        base64_string = base64.b64encode(processed_bytes).decode('utf-8')
        
        # Validate base64 (quick check)
        if not base64_string or len(base64_string) < 100:
            raise ValueError("Base64 string too short or empty")
        
        logger.info(f"Image processed: original_size={len(image_bytes)}, processed_size={len(processed_bytes)}, base64_length={len(base64_string)}")
        
        return base64_string, 'jpeg'
        
    except Exception as e:
        logger.error(f"Error processing image: {e}")
        # Fallback: try direct encoding
        try:
            base64_string = base64.b64encode(image_bytes).decode('utf-8')
            if not base64_string or len(base64_string) < 100:
                raise ValueError("Fallback base64 encoding failed")
            logger.warning("Using fallback direct encoding")
            return base64_string, 'jpeg'
        except Exception as fallback_error:
            logger.error(f"Fallback encoding also failed: {fallback_error}")
            # Re-raise the original image processing exception to be caught by the caller
            raise e # Re-raise the original exception 'e' from the first try block


def analyze_image(image_bytes: bytes, user_id: Optional[int] = None, request_id: Optional[str] = None) -> dict:
    """
    Call OpenAI to analyze an image and return validated JSON matching OpenAIImageResponse.
    """
    start = time.time()
    hashed_user = _hash_user_id(user_id)
    rid = request_id or 'rid-none'

    try:
        # Process and encode image
        base64_image, image_format = _process_and_encode_image(image_bytes)
    except Exception as e:
        logger.error(f"Image processing failed for user={hashed_user}, request_id={rid}: {e}")
        raise OpenAIServiceError(f"image_encoding_failed: {str(e)}")

    # Get model configuration
    model = getattr(settings, 'OPENAI_VISION_MODEL', None) or getattr(settings, 'OPENAI_MODEL', None)
    if not model:
        raise OpenAIServiceError("missing OPENAI_VISION_MODEL in settings")
    
    timeout = getattr(settings, 'OPENAI_TIMEOUT', 30)  # Increased from 20 to 30

    client = OpenAI(api_key=settings.OPENAI_API_KEY)

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
        '  "calories_estimate": number,\n'
        '  "total_protein_g": number,\n'
        '  "total_fat_g:" number,\n'
        
        "}\n"
        "All numbers must be plain numbers (not strings). Use grams for carbs. "
        "Ensure total_carbs_g equals the sum of all component carbs."
    )

    user_message_text = (
        "Analyze this meal image and estimate carbs per component. "
        "Identify each food item, estimate its carbs in grams, then sum for total_carbs_g."
    )

    # Build message content with proper image format
    user_content = [
        {"type": "text", "text": user_message_text},
        {
            "type": "image_url",
            "image_url": {
                "url": f"data:image/{image_format};base64,{base64_image}",
                "detail": "high"  # Request high detail analysis
            }
        },
    ]

    max_retries = 2
    attempt = 0
    last_exc = None

    while attempt <= max_retries:
        attempt += 1
        try:
            logger.info(f"Sending OpenAI request: user={hashed_user}, request_id={rid}, attempt={attempt}")
            
            # Send request to OpenAI
            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_instruction},
                    {"role": "user", "content": user_content},
                ],
                max_tokens=1000,  # Increased from 800
                temperature=0,
                timeout=timeout,
                response_format={"type": "json_object"},
            )
            
            # Extract response
            raw_text = resp.choices[0].message.content
            logger.debug(f"OpenAI raw response: {raw_text[:200]}...")
            
            # The response should be a clean JSON string due to response_format
            json_text = raw_text
            
            # Parse JSON
            parsed = json.loads(json_text)
            
            # Validate with pydantic
            validated = OpenAIImageResponse.parse_obj(parsed)
            
            # Verify total_carbs_g matches sum of components
            component_sum = sum(c.carbs_g for c in validated.components)
            if abs(component_sum - validated.total_carbs_g) > 0.1:
                logger.warning(
                    f"Carbs mismatch: sum={component_sum}, total={validated.total_carbs_g}. Using sum."
                )
                validated.total_carbs_g = component_sum
            
            duration = time.time() - start
            logger.info(
                f"openai_success user={hashed_user} request_id={rid} "
                f"latency={duration:.3f}s name={validated.name} "
                f"components={len(validated.components)} carbs={validated.total_carbs_g}g"
            )
            
            return validated.dict()

        except json.JSONDecodeError as je:
            logger.error(f"JSON decode error for user={hashed_user}, request_id={rid}: {je}")
            logger.error(f"Attempted to parse: {json_text[:500]}")
            raise OpenAIServiceError("model_returned_invalid_json")
            
        except ValidationError as ve:
            logger.warning(f"openai_invalid_json user={hashed_user} request_id={rid} error={ve}")
            logger.error(f"Validation failed for: {parsed}")
            raise OpenAIServiceError("model_returned_invalid_schema")
            
        except openai.BadRequestError as bre:
            logger.error(f"OpenAI BadRequest for user={hashed_user}, request_id={rid}: {bre}")
            # This usually means invalid base64 or image format
            raise OpenAIServiceError(f"invalid_image_request: {str(bre)}")
            
        except openai.APITimeoutError:
            logger.warning(f"openai_timeout user={hashed_user} request_id={rid} attempt={attempt}")
            if attempt > max_retries:
                raise OpenAITimeout("timeout")
            time.sleep(2)  # Wait longer before retry
            continue
            
        except openai.RateLimitError:
            logger.warning(f"openai_rate_limited user={hashed_user} request_id={rid} attempt={attempt}")
            if attempt > max_retries:
                raise OpenAITooManyRequests("rate_limited")
            time.sleep(2)
            continue
            
        except Exception as exc:
            last_exc = exc
            msg = str(exc).lower()
            
            # Check for rate limiting
            if "rate limit" in msg or "429" in msg:
                logger.warning(f"openai_rate_limited user={hashed_user} request_id={rid} attempt={attempt}")
                if attempt > max_retries:
                    raise OpenAITooManyRequests("rate_limited")
                time.sleep(2)
                continue
                
            # Check for timeout
            if "timeout" in msg or "timed out" in msg:
                logger.warning(f"openai_timeout user={hashed_user} request_id={rid}")
                if attempt > max_retries:
                    raise OpenAITimeout("timeout")
                time.sleep(2)
                continue
                
            # Retry on other errors
            if attempt <= max_retries:
                logger.warning(
                    f"openai_api_error user={hashed_user} request_id={rid} "
                    f"attempt={attempt} error={str(exc)}"
                )
                time.sleep(2)
                continue
                
            # Final failure
            logger.exception(f"openai_unexpected_final user={hashed_user} request_id={rid}")
            raise OpenAIServiceError(f"unexpected_error: {str(exc)}")
    
    # If we exhausted retries
    error_msg = str(last_exc) if last_exc else "unknown_error"
    logger.error(f"All retries exhausted for user={hashed_user}, request_id={rid}: {error_msg}")
    raise OpenAIServiceError(error_msg)