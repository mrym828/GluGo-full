from rest_framework import viewsets, permissions, status
from ..serializers import FoodEntrySerializer, GlucoseRecordSerializer, InsulinDoseSerializer
from datetime import datetime
import math
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.throttling import UserRateThrottle
from rest_framework.parsers import MultiPartParser, FormParser
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from datetime import timezone as dt_timezone
from django.utils.dateparse import parse_datetime
from ..models import (
    LibreConnection, NutritionalInfo,
    GlucoseRecord, FoodEntry, InsulinDose
)
from ..utils import estimate_components_carbs
from .insulin import calculate_insulin
from .libre import (
    build_authorize_url, exchange_code_for_token,
    login_with_password,
)
import requests
from .openai_service import (
    analyze_image, OpenAIServiceError, 
    OpenAITimeout, OpenAITooManyRequests
)
import uuid
import logging
import time
import hashlib
import os, hmac
from hashlib import sha256
import base64
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from typing import Optional
from ..services.prediction import prediction_service, TORCH_AVAILABLE, LIGHTGBM_AVAILABLE

@csrf_exempt
def csrf_token_view(request):
    return JsonResponse({'csrfToken': 'set'})

@csrf_exempt
def csrf_html_view(request):
    return render(request, 'csrf.html')

try:
    from pydantic import BaseModel, ValidationError
except Exception:
    BaseModel = None
    ValidationError = Exception

logger = logging.getLogger(__name__)


class FoodEntryViewSet(viewsets.ModelViewSet):
    queryset = FoodEntry.objects.none()
    serializer_class = FoodEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user and user.is_authenticated:
            return FoodEntry.objects.filter(user=user)
        return FoodEntry.objects.none()

    def perform_create(self, serializer):
        # Save the instance first
        instance = serializer.save(user=self.request.user)

        # Extract carbs from request data
        total_carbs = None
        
        # Try to get from direct field
        if 'total_carbs' in self.request.data:
            try:
                total_carbs = float(self.request.data['total_carbs'])
            except (ValueError, TypeError):
                pass
        
        # Try alternative field names
        if total_carbs is None and 'total_carbs_g' in self.request.data:
            try:
                total_carbs = float(self.request.data['total_carbs_g'])
            except (ValueError, TypeError):
                pass
        
        # Try from nutritional_info if present
        if total_carbs is None and instance.nutritional_info:
            try:
                total_carbs = float(instance.nutritional_info.carbs)
            except (ValueError, TypeError, AttributeError):
                pass
        
        # Save carbs to instance if found
        update_fields = []
        if total_carbs is not None:
            instance.total_carbs = total_carbs
            update_fields.append('total_carbs')
            
            # Also save other nutrition if available
            if 'total_calories' in self.request.data or 'calories_estimate' in self.request.data:
                try:
                    instance.total_calories = float(
                        self.request.data.get('total_calories') or 
                        self.request.data.get('calories_estimate', 0)
                    )
                    update_fields.append('total_calories')
                except (ValueError, TypeError):
                    pass
            
            if update_fields:
                instance.save(update_fields=update_fields)
        
        # Calculate insulin recommendation
        if total_carbs and total_carbs > 0:
            user = self.request.user
            carb_ratio = getattr(self.request.user, 'insulin_to_carb_ratio', None) 
            correction_factor = getattr(self.request.user, 'correction_factor', None)
            target_min = getattr(user, 'target_glucose_min', 70)
            target_max = getattr(user, 'target_glucose_max', 180)

            current_glucose = None
            try:
                latest = self.request.user.glucose_records.order_by('-timestamp').first()
                if latest:
                    current_glucose = latest.glucose_level
            except Exception:
                current_glucose = None

            if carb_ratio and carb_ratio > 0:
                try:
                    res = calculate_insulin(
                         total_carbs_g=total_carbs,
                        carb_ratio=float(carb_ratio),
                        current_glucose=float(current_glucose) if current_glucose else None,
                        target_bg=float(target_min) if target_min else 100.0,
                        target_range=(float(target_min), float(target_max)) if target_min and target_max else None,
                        correction_factor=float(correction_factor) if correction_factor else None,
                    )
                    
                    instance.insulin_recommended = res.get('recommended_dose')
                    instance.insulin_rounded = res.get('rounded_dose')
                    insulin_update_fields = ['insulin_recommended', 'insulin_rounded']
                    if 'total_carbs' not in update_fields:
                        insulin_update_fields.append('total_carbs')
                        
                    instance.save(update_fields=insulin_update_fields)
                except Exception as e:
                    logger.error(f"Insulin calculation failed: {e}")

class GlucoseRecordViewSet(viewsets.ModelViewSet):
    queryset = GlucoseRecord.objects.all()
    serializer_class = GlucoseRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return GlucoseRecord.objects.filter(user=self.request.user)
        

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class InsulinDoseViewSet(viewsets.ModelViewSet):
    """
    Confirmed insulin doses — distinct from FoodEntry.insulin_recommended
    (an advisory number, never confirmed as taken). Feeds the ML
    prediction pipeline's IOB feature (see prediction.py's
    prepare_user_data).
    """
    queryset = InsulinDose.objects.all()
    serializer_class = InsulinDoseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return InsulinDose.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class GlucoseStatisticsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')

        # Filter user’s glucose records
        records = GlucoseRecord.objects.filter(user=request.user)

        # If frontend sends a date range, apply it
        if start_date and end_date:
            start_date = parse_datetime(start_date)
            end_date = parse_datetime(end_date)

            # If parsing fails, fallback to timezone.now()
            if not start_date or not end_date:
                end_date = timezone.now()
                start_date = end_date - timezone.timedelta(days=7)

            records = records.filter(timestamp__range=[start_date, end_date])
        else:
            # Default: last 7 days
            end_date = timezone.now()
            start_date = end_date - timezone.timedelta(days=7)
            records = records.filter(timestamp__range=[start_date, end_date])


        # If no data found, return default zeros
        if not records.exists():
            return Response({
                "time_in_range": 0,
                "avg_glucose": 0,
                "above_range": 0,
                "below_range": 0,
                "coefficient_of_variation": 0,
                "period": "No data"
            })

        values = [r.glucose_level for r in records]

        # Compute averages
        avg_glucose = sum(values) / len(values)
        above_range = sum(1 for v in values if v > 180) / len(values) * 100
        below_range = sum(1 for v in values if v < 70) / len(values) * 100
        in_range = 100 - above_range - below_range

        # Compute coefficient of variation
        mean = avg_glucose
        variance = sum((v - mean) ** 2 for v in values) / len(values)
        std_dev = math.sqrt(variance)
        cv = (std_dev / mean) * 100 if mean != 0 else 0

        return Response({
            "time_in_range": round(in_range, 1),
            "avg_glucose": round(avg_glucose, 1),
            "above_range": round(above_range, 1),
            "below_range": round(below_range, 1),
            "coefficient_of_variation": round(cv, 1),
            "period": "Last 7 days"
        })

class HealthSyncView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        access_token = user.google_fit_token

        if not access_token:
            return Response({'error': 'missing_google_fit_token'}, status= 400)

        headers= {
            'authorization': f'Bearer {access_token}',
            'content-type': 'application/json',
        }
        import time
        end_time = int(time.time() * 1000)
        start_time = end_time - (7 * 24 * 60 * 60 * 1000)  # last 7 days

        body = {
            "aggregateBy": [
                {
                    "dataTypeName": "com.google.glucose.blood_glucose",
                }],
                "bucketByTime": { "durationMillis": 86400000 },
                "startTimeMillis": start_time,
                "endTimeMillis": end_time
        }
        url = 'https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate'
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=10)
            data = resp.json()
            return Response({'steps': data}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)
   

class LibreConnectView(APIView):
    """Endpoint for a user to register LibreView credentials (recommended to use token instead).

    The POST body should include `email` and either a `password` or `account_id`.
    We store the password using the small signing helper (dev-safe) to avoid
    leaving plaintext in the DB; for production, replace this with strong
    encryption or a token-based flow.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        body = request.data
        if getattr(settings, 'LIBRE_STATIC_ENABLED', False):
            email = getattr(settings, 'LIBRE_STATIC_EMAIL', None)
            password = getattr(settings, 'LIBRE_STATIC_PASSWORD', None)
            account_id = None
        else:
            email = body.get('email')
            password = body.get('password')
            account_id = body.get('account_id')
        
        code = body.get('code')
        redirect_uri = body.get('redirect_uri')

        if not email or not (password or account_id):
            return Response({'error': 'email and password or account_id required'}, status=status.HTTP_400_BAD_REQUEST)

        # FIXED: Use get_or_create instead of create to avoid IntegrityError
        lc, created = LibreConnection.objects.get_or_create(user=user)
        
        lc.email = email or lc.email
        if password:
            lc.set_password_encrypted(password)
        if account_id:
            lc.account_id = account_id

       
        if code and redirect_uri:
            try:
                token_data = exchange_code_for_token(code, redirect_uri)
                lc.set_token_data(token_data)
            except Exception as e:
                return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        
        lc.save()
        return Response({'status': 'connected', 'created': created}, status=status.HTTP_200_OK)


class LibreWebhookView(APIView):
    """Accept incoming glucose readings from LibreView (if webhook is configured)."""
    permission_classes = [AllowAny]

    def post(self, request):
        # Webhook signature verification logic would go here
        data = request.data
        user_id = data.get('id')
        if not user_id:
            return Response({'error': 'user_id required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            user = User.objects.get(id=user_id)
        except:
            return Response({'error': 'user not found'}, status=status.HTTP_404_NOT_FOUND)
        
        glucose_level = data.get('glucose_level')
        timestamp_str = data.get('timestamp')
        
        if glucose_level is None or not timestamp_str:
            return Response({'error': 'glucose_level and timestamp required'}, status=status.HTTP_400_BAD_REQUEST)
        
        timestamp = parse_datetime(timestamp_str)
        if not timestamp:
            return Response({'error': 'invalid timestamp format'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Create glucose record
        GlucoseRecord.objects.get_or_create(
            user=user,
            timestamp=timestamp,
            source='libre_webhook',
            defaults={
                'glucose_level': glucose_level,
                'trend_arrow': data.get('trend_arrow', '')
            }
        )
        
        return Response({'status': 'received'}, status=status.HTTP_200_OK)


class InsulinCalculateView(APIView):
    """Calculate insulin dose based on carbs and current glucose."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
     try:   
        user = request.user
        data = request.data
        
        total_carbs = data.get('total_carbs_g')
        if total_carbs is None:
            return Response(
                {'success': False, 'error': 'total_carbs_g is required'},
                    status=status.HTTP_400_BAD_REQUEST
            )
        
        carb_ratio = getattr(user, 'insulin_to_carb_ratio', None) 
        correction_factor = getattr(user, 'correction_factor', None)
        target_min = getattr(user, 'target_glucose_min', 70)
        target_max = getattr(user, 'target_glucose_max', 180)
        
        if not carb_ratio or carb_ratio <= 0:
                return Response(
                    {
                        'success': False,
                        'error': 'Carb ratio not configured. Please update your profile settings.'
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
        current_glucose = request.data.get('current_glucose')
        iob = float(request.data.get('iob',0.0))
        min_dose = float(request.data.get('min_dose', 0.0))
        max_dose = float(request.data.get('max_dose', 25.0))
        round_to = float(request.data.get('round_to', 0.5))

        if current_glucose is None:
                try:
                    latest = user.glucose_records.order_by('-timestamp').first()
                    if latest:
                        current_glucose = latest.glucose_level
                except Exception:
                    pass

        predicted_glucose = None
        try:
            pred_result = prediction_service.predict_for_user(user, model_type='ensemble')
            if pred_result.get('success'):
                predicted_glucose = pred_result['prediction']['glucose_mg_dl']
        except Exception as e:
            logger.error(f"Prediction lookup for insulin calc failed: {e}")

        result = calculate_insulin(
                total_carbs_g=float(total_carbs),
                carb_ratio=float(carb_ratio),
                current_glucose=float(current_glucose) if current_glucose else None,
                target_bg=float(target_min) if target_min else None,
                target_range=(float(target_min), float(target_max)) if target_min and target_max else None,
                correction_factor=float(correction_factor) if correction_factor else None,
                iob=iob,
                min_dose=min_dose,
                max_dose=max_dose,
                round_to=round_to,
                predicted_glucose=float(predicted_glucose) if predicted_glucose is not None else None,
        )
        
        return Response({
                'success': True,
                'calculation': result,
                'user_settings': {
                    'carb_ratio': float(carb_ratio),
                    'correction_factor': float(correction_factor) if correction_factor else None,
                    'target_glucose_min': float(target_min) if target_min else None,
                    'target_glucose_max': float(target_max) if target_max else None,
                },
                'timestamp': timezone.now().isoformat()
            })
            
     except ValueError as e:
        return Response(
            {'success': False, 'error': f'Invalid input: {str(e)}'},
            status=status.HTTP_400_BAD_REQUEST
        )
     except Exception as e:
        logger.exception('Insulin calculation failed')
        return Response(
            {'success': False, 'error': 'Calculation error'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


class LibreOAuthStartView(APIView):
    """Generate OAuth authorization URL for LibreView."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        redirect_uri = request.data.get('redirect_uri')
        if not redirect_uri:
            return Response({'error': 'redirect_uri required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Generate PKCE challenge/verifier and state
            import secrets
            state = secrets.token_urlsafe(32)
            code_verifier = secrets.token_urlsafe(64)
            code_challenge = base64.urlsafe_b64encode(
                hashlib.sha256(code_verifier.encode()).digest()
            ).decode().rstrip('=')
            
            # Store verifier in cache with state as key
            cache.set(f"pkce:{state}:{request.user.id}", code_verifier, timeout=600)
            
            auth_url = build_authorize_url(
                redirect_uri=redirect_uri,
                state=state,
                code_challenge=code_challenge
            )
            
            return Response({
                'authorization_url': auth_url,
                'state': state
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibrePasswordLoginView(APIView):
    """Login to LibreView using email/password and store tokens."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        
        if not email or not password:
            return Response({'error': 'email and password required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            base_url, token_response, auth_headers = login_with_password(email, password)
            
            if not token_response or not auth_headers:
                return Response({'error': 'login failed'}, status=status.HTTP_401_UNAUTHORIZED)
            
            user = request.user
            lc, created = LibreConnection.objects.get_or_create(user=user)
            
            lc.email = email
            lc.api_endpoint = base_url
            lc.token = token_response.get('access_token')
            lc.account_id = token_response.get('account_id')
            lc.connected = True
            lc.region = base_url.split('//api-')[1].split('.')[0] if 'api-' in base_url else None
            lc.save()
            
            return Response({
                'status': 'connected',
                'region': lc.region,
                'created': created,
                'email': email,
                'message': 'Successfully connected to LibreView'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception('LibrePasswordLogin failed')
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibreSyncNowView(APIView):
    """Fetch latest glucose readings from LibreView on-demand."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user

        # 1) Try to get saved connection
        try:
            conn = user.libre_connection
        except LibreConnection.DoesNotExist:
            conn = None

        base_url = None
        token = None
        account_id = None

        if conn and conn.api_endpoint and conn.token and conn.account_id:
            base_url = conn.api_endpoint
            token = conn.token
            account_id = conn.account_id
        else:
            # 2) Fallback to one-off login via email/password in body
            email = request.data.get("email")
            password = request.data.get("password")
            if not email or not password:
                return Response(
                    {"error": "missing_credentials_or_connection"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            base_url, token_response, auth_headers = login_with_password(email, password)
            if not auth_headers or not token_response:
                return Response({"error": "libre_login_failed"}, status=400)
            token = token_response.get("access_token")
            account_id = token_response.get("account_id")

            
            LibreConnection.objects.update_or_create(
                user=user,
                defaults={
                    "api_endpoint": base_url,
                    "token": token,
                    "account_id": account_id,
                    "connected": True if token else False,
                    "region": (base_url.split('//api-')[1].split('.')[0]
                    if "api-" in base_url
                    else None),

                },
            )

        # 3) Call LLU /connections
        from .libre import get_libreview_connection
        try:
            payload = get_libreview_connection(base_url, token, account_id)
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 401:
                if conn:
                    conn.connected = False
                    conn.save(update_fields=["connected"])
                return Response(
                    {
                        "error": "libre_session_expired",
                        "message": "Your LibreView session has expired. Please reconnect your account.",
                    },
                    status=401,
                )
            return Response({"error": f"llu_request_failed: {e}"}, status=502)
        except Exception as e:
            return Response({"error": f"llu_request_failed: {e}"}, status=502)

        # 4) Extract readings and save idempotently
        data = payload.get("data") or []
        fetched = 0
        created = 0

        for item in data:
            gm = (item or {}).get("glucoseMeasurement") or {}
            # Some entries may not have a current measurement
            if not gm:
                continue

            value = gm.get("Value")
            trend = gm.get("TrendArrow")
            # FactoryTimestamp is LibreView's UTC timestamp; "Timestamp" is
            # local sensor time in the account's region and must not be
            # treated as UTC (it was previously, causing a several-hour
            # skew on every synced reading).
            ts_str = gm.get("FactoryTimestamp") or gm.get("Timestamp") or gm.get("timestamp")
            if value is None or not ts_str:
                continue

            fetched += 1
            
            try:
                ts = datetime.strptime(ts_str, "%m/%d/%Y %I:%M:%S %p")
                ts = timezone.make_aware(ts, dt_timezone.utc)
            except ValueError:

                ts = parse_datetime(ts_str)
                if ts is None:
                    # If Libre sends naive string like "2025-10-30T12:00:00", make it UTC
                    try:
                        ts = timezone.make_aware(datetime.fromisoformat(ts_str))
                    except Exception:
                        continue
                if timezone.is_naive(ts):
                    ts = timezone.make_aware(ts, dt_timezone.utc)


            obj, was_created = GlucoseRecord.objects.get_or_create(
                user=user,
                timestamp=ts,
                source="libre",
                defaults={
                    'glucose_level': value,
                    'trend_arrow': trend
                }
            )
            if was_created:
                created += 1

                # Get the latest glucose record after sync
        latest_record = GlucoseRecord.objects.filter(
            user=user,
            source="libre"
        ).order_by('-timestamp').first()

        response_data = {
            "fetched": fetched,
            "created": created,
            "records_synced": created
        }

        # Add latest reading if available
        if latest_record:
            response_data["latest_reading"] = {
                "glucose_level": latest_record.glucose_level,
                "trend_arrow": latest_record.trend_arrow,
                "timestamp": latest_record.timestamp.isoformat(),
            }

        return Response(response_data, status=200)


class LibreOAuthCallbackView(APIView):
    """Accept an authorization code (POST) and exchange it for tokens server-side.

    POST payload: { code: string, redirect_uri: string }
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        body = request.data
        code = body.get('code')
        redirect_uri = body.get('redirect_uri')
        state = body.get('state')
        if not code or not redirect_uri:
            return Response({'error': 'code and redirect_uri required'}, status=status.HTTP_400_BAD_REQUEST)
        if not state:
            return Response({'error': 'state required'}, status=status.HTTP_400_BAD_REQUEST)    

        user = request.user
        lc, _ = LibreConnection.objects.get_or_create(user=user)
        try:
            verifier = cache.get(f"pkce:{state}:{user.id}")
            token_data = exchange_code_for_token(code, redirect_uri, code_verifier=verifier)
            lc.set_token_data(token_data)
            cache.delete(f"pkce:{state}:{user.id}")
            return Response({'status': 'ok'})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class LibreConnectionStatusView(APIView):
    """
    Check LibreView connection status.
    
    GET /api/core/libre/status/
    
    Returns:
    {
        "connected": true,
        "email": "user@example.com",
        "account_id": "abc123",
        "region": "eu",
        "last_synced": "2025-11-15T10:30:00Z"
    }
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            connection = LibreConnection.objects.get(user=request.user)
            
            return Response({
                'connected': connection.connected,
                'email': connection.email,
                'account_id': connection.account_id,
                'region': connection.region,
                'last_synced': connection.last_synced,
                'api_endpoint': connection.api_endpoint
            })
        except LibreConnection.DoesNotExist:
            return Response({
                'connected': False,
                'email': None,
                'account_id': None,
                'region': None,
                'last_synced': None
            })
        
class LibreDisconnectView(APIView):
    """
    Disconnect LibreView account.
    
    POST /api/core/libre/disconnect/
    
    Returns:
    {
        "status": "disconnected",
        "message": "LibreView account disconnected successfully"
    }
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            connection = LibreConnection.objects.get(user=request.user)
            connection.disconnect()
            
            logger.info(f"LibreView disconnected for user {request.user.id}")
            
            return Response({
                'status': 'disconnected',
                'message': 'LibreView account disconnected successfully'
            })
        except LibreConnection.DoesNotExist:
            return Response(
                {'error': 'No LibreView connection found'},
                status=status.HTTP_404_NOT_FOUND
            )

class OpenAIAnalyzeImageView(APIView):
    """Production-ready image->nutrition endpoint.

    Requirements implemented:
    - JWT (SimpleJWT) required via global REST_FRAMEWORK setting
    - Per-user rate limit (throttle_scope='ai_image')
    - Accept only image/jpeg or image/png, max 4 MB
    - Timeout and simple retries handled in service
    - Strict JSON validated via Pydantic in `openai_service`
    - EXIF stripping performed server-side
    """
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [UserRateThrottle]
    throttle_scope = 'ai_image'

    def post(self, request, *args, **kwargs):
        f = request.FILES.get('image') or request.FILES.get('file')
        if not f:
            return Response({"details" : "No image provided (use field 'image')."}, status=400)

        user = request.user
        request_id = request.headers.get('X-Request-Id') or str(uuid.uuid4())

        # Content type check
        content_type = f.content_type
        if content_type not in ('image/jpeg', 'image/png'):
            return Response({'error': 'unsupported_media_type'}, status=status.HTTP_400_BAD_REQUEST)

        # Size check (max 4MB)
        max_bytes = 4 * 1024 * 1024
        if f.size > max_bytes:
            return Response({'error': 'file_too_large'}, status=status.HTTP_400_BAD_REQUEST)

        # Read bytes (do not log)
        image_bytes = f.read()

        # Call service
        try:
            start = time.time()
            result = analyze_image(image_bytes=image_bytes, user_id=getattr(user, 'id', None), request_id=request_id)
            latency = time.time() - start
            user_hash = hashlib.sha256(str(getattr(user, 'id', None)).encode('utf-8')).hexdigest()[:16]
            logger.info('ai_request success user=%s request_id=%s latency=%.3f', user_hash, request_id, latency)
            return Response(result)
        except OpenAITimeout:
            user_hash = hashlib.sha256(str(getattr(user, 'id', None)).encode('utf-8')).hexdigest()[:16]
            logger.warning('ai_request timeout user=%s request_id=%s', user_hash, request_id)
            return Response({'error': 'upstream_timeout'}, status=status.HTTP_504_GATEWAY_TIMEOUT)
        except OpenAITooManyRequests:
            user_hash = hashlib.sha256(str(getattr(user, 'id', None)).encode('utf-8')).hexdigest()[:16]
            logger.warning('ai_request rate_limited user=%s request_id=%s', user_hash, request_id)
            return Response({'error': 'rate_limited'}, status=status.HTTP_429_TOO_MANY_REQUESTS)
        except OpenAIServiceError as se:
            user_hash = hashlib.sha256(str(getattr(user, 'id', None)).encode('utf-8')).hexdigest()[:16]
            logger.error('ai_request upstream_fail user=%s request_id=%s error=%s', user_hash, request_id, str(se))
            return Response({'error': 'upstream_model_error'}, status=status.HTTP_502_BAD_GATEWAY)
        except Exception as exc:
            user_hash = hashlib.sha256(str(getattr(user, 'id', None)).encode('utf-8')).hexdigest()[:16]
            logger.exception('ai_request unexpected user=%s request_id=%s', user_hash, request_id)
            return Response({'error': 'internal_error'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
class GlucosePredictionView(APIView):
    """
    Predict glucose levels 30 minutes ahead based on current trends.
    
    Endpoint: GET /api/core/glucose/predict/
    
    What this does:
    - Fetches your last 4 hours of glucose readings
    - Runs machine learning models to predict where your glucose will be in 30 minutes
    - Uses ensemble of CNN-LSTM, LightGBM, and simple baseline models
    
    Query parameters:
    - model: Which model to use (default: 'ensemble')
      * 'ensemble': Combines all models (best accuracy)
      * 'cnn_lstm': Deep learning model only
      * 'lgb': LightGBM model only  
      * 'simple': Simple average baseline
    - lookback: Minutes of history to use (default: 240 = 4 hours)
    
    Example request:
    GET /api/core/glucose/predict/?model=ensemble&lookback=240
    
    Example response:
    {
        "success": true,
        "prediction": {
            "glucose_mg_dl": 165.3,
            "time_horizon_minutes": 30,
            "predictions_by_model": {
                "cnn_lstm": 168.2,
                "lgb": 163.5,
                "simple": 164.0
            },
            "risk_assessment": {
                "level": "normal",
                "current": 160.0,
                "predicted": 165.3,
                "change": 5.3
            },
            "current_glucose": 160.0,
            "change": 5.3,
            "timestamp": "2025-11-23T10:30:00Z"
        },
        "metadata": {
            "model_used": "ensemble",
            "available_models": ["cnn_lstm", "lgb", "simple"],
            "data_points_used": 48
        }
    }
    
    Use cases:
    - Check if glucose is trending up or down
    - Get early warning before going out of range
    - See which direction glucose is heading
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        try:
            model_type = request.query_params.get('model', 'ensemble')
            lookback = int(request.query_params.get('lookback', 240))
            
            valid_models = ['ensemble', 'cnn_lstm', 'lgb', 'simple']
            if model_type not in valid_models:
                return Response(
                    {'success': False, 'error': f'Invalid model. Choose from: {valid_models}'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            result = prediction_service.predict_for_user(
                user=request.user,
                model_type=model_type,
                lookback_minutes=lookback
            )
            
            return Response(result, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response(
                {'success': False, 'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.exception('Glucose prediction failed')
            return Response(
                {'success': False, 'error': 'Prediction service error'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class MealGlucosePredictionView(APIView):
    """
    Predict glucose levels 30 minutes after eating a meal.
    
    Endpoint: POST /api/core/glucose/predict-meal/
    
    What this does:
    - Takes meal information (carbs and optional insulin dose)
    - Predicts how the meal will affect your glucose in 30 minutes
    - Calculates meal impact using your carb ratio and correction factor
    - Provides timeline showing glucose at 0, 10, 20, 30 minutes
    - Gives risk assessment (low/normal/high/extreme)
    
    Request body:
    {
        "carbs": 45.5,         // REQUIRED: carbohydrates in grams
        "insulin": 4.5,        // Optional: insulin dose in units (default: 0)
        "model": "ensemble",   // Optional: model type (default: "ensemble")
        "lookback": 240        // Optional: lookback minutes (default: 240)
    }
    
    Example request:
    POST /api/core/glucose/predict-meal/
    {
        "carbs": 60,
        "insulin": 5,
        "model": "ensemble"
    }
    
    Example response:
    {
        "success": true,
        "prediction": {
            "glucose_mg_dl": 185.3,
            "time_horizon_minutes": 30,
            "predictions_by_model": {
                "cnn_lstm": 168.2,
                "lgb": 163.5,
                "simple": 164.0
            },
            "risk_assessment": {
                "level": "high",
                "message": "Warning: Predicted glucose (185.3 mg/dL) is above target range."
            },
            "current_glucose": 140.0,
            "change": 45.3,
            "timeline": [
                {"minutes": 0, "glucose": 140.0, "timestamp": "2025-11-23T12:00:00Z"},
                {"minutes": 10, "glucose": 155.7, "timestamp": "2025-11-23T12:10:00Z"},
                {"minutes": 20, "glucose": 172.4, "timestamp": "2025-11-23T12:20:00Z"},
                {"minutes": 30, "glucose": 185.3, "timestamp": "2025-11-23T12:30:00Z"}
            ],
            "meal_impact": 45.3
        },
        "meal_info": {
            "carbs_g": 60,
            "insulin_units": 5
        },
        "metadata": {
            "model_used": "ensemble",
            "available_models": ["cnn_lstm", "lgb", "simple"],
            "data_points_used": 48
        }
    }
    
    Use cases:
    - Before eating: "Should I take more insulin with this meal?"
    - Meal planning: "Will this meal spike my glucose?"
    - Insulin dosing: "Is my current insulin dose enough?"
    - Real-time decision making during meals
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            user = request.user

            # Validate required field: carbs
            carbs = request.data.get('carbs')
            if carbs is None:
                return Response(
                    {'success': False, 'error': 'Carbs value is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate carbs range
            try:
                carbs = float(carbs)
                if carbs < 0 or carbs > 500:
                    return Response(
                        {'success': False, 'error': 'Carbs must be between 0 and 500g'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            except (ValueError, TypeError):
                return Response(
                    {'success': False, 'error': 'Invalid carbs value'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            carb_ratio = getattr(user, 'insulin_to_carb_ratio', None)
            correction_factor = getattr(user, 'correction_factor', None)
            target_min = getattr(user, 'target_glucose_min', 70)
            target_max = getattr(user, 'target_glucose_max', 180)

            current_glucose = None
            try:
                latest = user.glucose_records.order_by('-timestamp').first()
                if latest:
                    current_glucose = latest.glucose_level
            except Exception:
                pass

            # Optional model and lookback parameters
            model_type = request.data.get('model', 'ensemble')
            lookback = int(request.data.get('lookback', 240))

            # Baseline "no insulin" meal forecast, used later for the
            # with/without comparison shown to the user.
            result_without_insulin = prediction_service.predict_after_meal(
                user=user,
                meal_carbs=carbs,
                meal_insulin=0,
                model_type=model_type,
                lookback_minutes=lookback
            )

            # Where is glucose headed independent of this meal (ML ensemble
            # forecast from historical CGM trend)? This is what feeds
            # calculate_insulin as a hypo-safety check on the correction
            # dose below. Unlike the carbs-only baseline above (which can
            # only predict flat/rising, since meal_impact >= 0 for carbs
            # >= 0), this can genuinely reflect a falling trend.
            trend_prediction = prediction_service.predict_for_user(
                user=user, model_type=model_type, lookback_minutes=lookback
            )
            predicted_glucose_baseline = None
            if trend_prediction.get('success'):
                predicted_glucose_baseline = trend_prediction['prediction']['glucose_mg_dl']

            # Calculate recommended insulin dose using insulin.py
            insulin_calc = None
            recommended_insulin = 0

            if carb_ratio and carb_ratio > 0:
                try:
                    insulin_calc = calculate_insulin(
                        total_carbs_g=carbs,
                        carb_ratio=float(carb_ratio),
                        current_glucose=float(current_glucose) if current_glucose else None,
                        target_bg=float(target_min) if target_min else None,
                        target_range=(float(target_min), float(target_max)) if target_min and target_max else None,
                        correction_factor=float(correction_factor) if correction_factor else None,
                        predicted_glucose=predicted_glucose_baseline,
                    )
                    recommended_insulin = insulin_calc.get('rounded_dose', 0)
                except Exception as e:
                    logger.error(f"Insulin calculation failed: {e}")

            # Use provided insulin or calculated recommendation
            insulin_to_use = request.data.get('insulin')
            if insulin_to_use is not None:
                try:
                    insulin_to_use = float(insulin_to_use)
                except (ValueError, TypeError):
                    insulin_to_use = recommended_insulin
            else:
                insulin_to_use = recommended_insulin

            # WITH insulin (recommended dose or user-provided)
            result_with_insulin = prediction_service.predict_after_meal(
                user=user,
                meal_carbs=carbs,
                meal_insulin=insulin_to_use,
                model_type=model_type,
                lookback_minutes=lookback
            )
            
            # Calculate comparison
            glucose_diff = 0
            recommendation = ""
            
            if result_with_insulin['success'] and result_without_insulin['success']:
                with_insulin_glucose = result_with_insulin['prediction']['glucose_mg_dl']
                without_insulin_glucose = result_without_insulin['prediction']['glucose_mg_dl']
                glucose_diff = without_insulin_glucose - with_insulin_glucose
                
                if glucose_diff > 50:
                    recommendation = f"Taking {insulin_to_use} units will prevent a significant glucose spike (difference: {glucose_diff:.1f} mg/dL)"
                elif glucose_diff > 20:
                    recommendation = f"Taking {insulin_to_use} units will help manage glucose levels (difference: {glucose_diff:.1f} mg/dL)"
                else:
                    recommendation = f"Minimal difference expected (difference: {glucose_diff:.1f} mg/dL)"
            
            return Response({
                'success': True,
                'with_insulin': {
                    'prediction': result_with_insulin.get('prediction'),
                    'insulin_dose': insulin_to_use,
                    'metadata': result_with_insulin.get('metadata')
                },
                'without_insulin': {
                    'prediction': result_without_insulin.get('prediction'),
                    'insulin_dose': 0,
                    'metadata': result_without_insulin.get('metadata')
                },
                'insulin_calculation': insulin_calc if insulin_calc else {
                    'note': 'Carb ratio not configured. Please update your profile.'
                },
                'comparison': {
                    'glucose_difference_mg_dl': round(glucose_diff, 1),
                    'recommendation': recommendation
                },
                'user_settings': {
                    'carb_ratio': float(carb_ratio) if carb_ratio else None,
                    'correction_factor': float(correction_factor) if correction_factor else None,
                    'target_range': [float(target_min), float(target_max)] if target_min and target_max else None
                }
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response(
                {'success': False, 'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.exception('Meal glucose prediction failed')
            return Response(
                {'success': False, 'error': 'Prediction service error'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class PredictionStatusView(APIView):
    """
    Check prediction service status and available models.
    
    Endpoint: GET /api/core/glucose/predict/status/
    
    What this does:
    - Shows which ML models are loaded and available
    - Checks if dependencies (PyTorch, LightGBM) are installed
    - Indicates service health
    
    Example response:
    {
        "success": true,
        "service_loaded": true,
        "available_models": {
            "cnn_lstm": true,
            "lgb": true,
            "simple": true,
            "ensemble": true
        },
        "dependencies": {
            "pytorch": true,
            "lightgbm": true
        },
        "message": "Prediction service ready"
    }
    
    Use cases:
    - Health check endpoint
    - Debugging: "Why aren't predictions working?"
    - Frontend: Disable prediction UI if models aren't loaded
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        return Response({
            'success': True,
            'service_loaded': prediction_service.loaded,
            'available_models': {
                'cnn_lstm': TORCH_AVAILABLE and prediction_service.cnn_lstm_model is not None,
                'lgb': LIGHTGBM_AVAILABLE and prediction_service.lgb_model is not None,
                'simple': True,  # Always available (simple average)
                'ensemble': prediction_service.loaded
            },
            'dependencies': {
                'pytorch': TORCH_AVAILABLE,
                'lightgbm': LIGHTGBM_AVAILABLE,
            },
            'message': 'Prediction service ready' if prediction_service.loaded 
                      else 'No ML models loaded, using baseline only'
        })


class QuickGlucosePredictionView(APIView):
    """
    Quick glucose prediction based on historical patterns using ML models.
    
    Endpoint: GET /api/core/glucose/predict/quick/
    
    What this does:
    - Uses CNN-LSTM/LightGBM models trained on historical glucose data
    - Predicts glucose 30 minutes ahead based on recent patterns
    - NO meal/insulin input - pure historical trend prediction
    
    Use case:
    - "What will my glucose be in 30 min if I do nothing?"
    - Display on home page as a quick trend indicator
    - Different from meal prediction which is scenario-based
    
    Example response:
    {
        "success": true,
        "prediction": {
            "glucose_mg_dl": 145.2,
            "time_horizon_minutes": 30,
            "current_glucose": 137.0,
            "change": 8.2,
            "trend": "rising",
            "predictions_by_model": {
                "cnn_lstm": 145.5,
                "lgb": 144.9,
                "simple": 145.0
            },
            "risk_assessment": {
                "level": "normal",
                "message": "Predicted glucose within target range"
            }
        },
        "metadata": {
            "model_used": "ensemble",
            "data_points_used": 48,
            "available_models": ["cnn_lstm", "lgb", "simple"]
        }
    }
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        try:
            user = request.user
            model_type = request.query_params.get('model', 'ensemble')
            lookback = int(request.query_params.get('lookback', 240))
            
            # Get prediction using historical data only
            result = prediction_service.predict_for_user(
                user=user,
                model_type=model_type,
                lookback_minutes=lookback
            )
            
            if not result['success']:
                # Not enough glucose history yet is an expected, unexceptional
                # state (e.g. a new account) — not a server error.
                return Response(result, status=status.HTTP_200_OK)

            # Add trend indicator
            current = result['prediction']['current_glucose']
            predicted = result['prediction']['glucose_mg_dl']
            change = predicted - current
            
            if change > 10:
                trend = 'rising'
            elif change < -10:
                trend = 'falling'
            else:
                trend = 'stable'
            
            result['prediction']['trend'] = trend
            
            # Add risk assessment if not present
            if 'risk_assessment' not in result['prediction']:
                risk_level = 'normal'
                risk_message = "Predicted glucose within target range"
                
                if predicted > 180:
                    risk_level = 'high'
                    risk_message = f"Warning: Predicted glucose ({predicted:.1f} mg/dL) above target"
                elif predicted < 70:
                    risk_level = 'low'
                    risk_message = f"Warning: Predicted glucose ({predicted:.1f} mg/dL) below target"
                
                result['prediction']['risk_assessment'] = {
                    'level': risk_level,
                    'message': risk_message
                }
            
            return Response(result, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.exception('Quick glucose prediction failed')
            return Response(
                {
                    'success': False,
                    'error': 'Prediction service error',
                    'details': str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )