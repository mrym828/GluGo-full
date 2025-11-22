import json
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils.dateparse import parse_datetime
from django.conf import settings
from django.db.models import Avg, Count
import uuid
import hashlib
import requests
from datetime import timedelta
from django.utils import timezone
from django.core.files.base import ContentFile
from .services.openai_service import analyze_image
from .services.insulin import calculate_insulin
from .services.libre import login_with_password, get_libreview_connection


DEFAULT_LOW_GLUC = 69
DEFAULT_HIGH_GLUC = 200

def _user_glucose_thresholds(user):
    try:
        low = getattr(user, 'target_glucose_min', None)
        high = getattr(user, 'target_glucose_max', None)
        low = float(low) if low is not None else DEFAULT_LOW_GLUC
        high = float(high) if high is not None else DEFAULT_HIGH_GLUC
        if low >= high:
            low,high = DEFAULT_LOW_GLUC, DEFAULT_HIGH_GLUC
        return low, high
    except Exception:
        return DEFAULT_LOW_GLUC, DEFAULT_HIGH_GLUC


class NutritionalInfo(models.Model):
    calories = models.FloatField(blank=True, null=True)
    carbs = models.FloatField(blank=True, null=True)
    sugar = models.FloatField(blank=True, null=True)
    protein = models.FloatField(blank=True, null=True)
    salt = models.FloatField(blank=True, null=True)
    fat = models.FloatField(blank=True, null=True)
    fiber = models.FloatField(blank=True, null=True)
    portion_size = models.CharField(max_length=100, blank=True, null=True)


    def get_carbs(self):
        return self.carbs

    def __str__(self):
        return f"NutritionalInfo(cal={self.calories}, carbs={self.carbs})"


class FoodEntry(models.Model):
    MEAL_TYPES = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('dinner', 'Dinner'),
        ('snack', 'Snack'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='food_entries')
    image = models.ImageField(upload_to='food_images/', blank=True, null=True)
    food_name = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    meal_type = models.CharField(max_length=16, choices=MEAL_TYPES, default="lunch")
    nutritional_info = models.OneToOneField(NutritionalInfo, on_delete=models.SET_NULL, null=True, blank=True)

    total_carbs = models.FloatField(null=True, blank=True, help_text="Total carbohydrates in grams")
    total_calories = models.FloatField(null=True, blank=True, help_text="Total calories")
    total_protein = models.FloatField(null=True, blank=True, help_text="Total protein in grams")
    total_fat = models.FloatField(null=True, blank=True, help_text="Total fat in grams")
  
    insulin_recommended = models.FloatField(blank=True, null=True)
    insulin_rounded = models.FloatField(blank=True, null=True)

   
    def analyze_food(self, image_file=None):
        """Placeholder for analysis, returns NutritionalInfo-like dict or object."""
        #resolve image bytes
        file_obj = image_file or getattr(self, "image", None)
        if not file_obj:
            return {"error": "no image found"}
        try:
            if hasattr(file_obj, "read"):
                image_bytes = file_obj.read()
            else:
                file_obj.open("rb")
                image_bytes = file_obj.read()
                file_obj.close()
        except Exception:
            return {"error": "failed to read image bytes"}
        #call openai 
        try:
            result = analyze_image(
                image_bytes=image_bytes,
                user_id=getattr(self.user, "id", None),
                request_id=str(self.id),
            )
        except Exception as e:
            return {"error": f"analysis failed: {e}"}
        
        #result 
        name = result.get("name")
        #components + carbs
        total_carbs = result.get("total_carbs_g")

        #update
        ni = self.nutritional_info or NutritionalInfo()
        ni.carbs = total_carbs
        ni.save()

        #attach to foodentry
        changed = False
        if not self.nutritional_info_id or self.nutritional_info_id != ni.id:
            self.nutritional_info = ni
            changed = True
        if name and (not self.food_name):
            self.food_name = name
            changed = True
        
        #insulin calc
        try:
            carb_ratio = getattr(self.user, "insulin_to_carb_ratio", None)
            correction_factor = getattr(self.user, "correction_factor", None)
            current_glucose = None
            try:
                latest = self.user.glucose_records.order_by('-timestamp').first()
                if latest:
                    current_glucose = latest.glucose_level
            except Exception:
                current_glucose = getattr(self.user, "current_glucose", None)

            if total_carbs is not None and carb_ratio:
                calc = calculate_insulin(
                    total_carbs_g=float(total_carbs),
                    carb_ratio=float(carb_ratio),
                    current_glucose=current_glucose,
                    correction_factor=correction_factor,
                )
                self.insulin_recommended = calc.get("recommended_dose")
                self.insulin_rounded = calc.get("rounded_dose")
                changed = True
        except Exception:
            pass

        if changed:
            self.save(update_fields=[
                "nutritional_info",
                "food_name",
                "insulin_recommended",
                "insulin_rounded",
            ])   
        return {
            **result,
            "nutritional_info_id": ni.id,
            "food_entry_id": str(self.id),
        }             

    def __str__(self):
        return f"FoodEntry({self.food_name or self.id})"


class GlucoseRecord(models.Model):
    SOURCE_CHOICES = [
        ("manual", "Manual"),
        ("libre", "Libre"),
        ("other", "Other")
    ]
    MEAL_TIMING_CHOICES = [
        ('before_meal', 'Before Meal'),
        ('after_meal', 'After Meal'),
        ('fasting', 'Fasting'),
        ('bedtime', 'Bedtime'),
        ('random', 'Random'),
    ]
    MOOD_CHOICES = [
        ('excellent', 'Excellent'),
        ('good', 'Good'),
        ('fair', 'Fair'),
        ('poor', 'Poor'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='glucose_records')
    timestamp = models.DateTimeField()
    glucose_level = models.FloatField()
    trend_arrow = models.CharField(max_length=50, blank=True, null=True)
    source = models.CharField(max_length=50, choices=SOURCE_CHOICES, default="manual")  # e.g., 'cgm' or 'manual'
    meal_timing = models.CharField(max_length=20, choices=MEAL_TIMING_CHOICES, blank=True, null=True)
    mood = models.CharField(max_length=20, choices=MOOD_CHOICES, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)  

  
    def is_abnormal(self, low_threshold=None, high_threshold=None):
        low, high = _user_glucose_thresholds(self.user)
        if low_threshold is not None:
            low = float(low_threshold)
        if high_threshold is not None:
            high = float(high_threshold)
        return not (low <= float(self.glucose_level) <= high)

    def __str__(self):
        return f"GlucoseRecord(user={self.user_id}, level={self.glucose_level} at {self.timestamp})"
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'timestamp']),
        ]
        constraints = [
            models.UniqueConstraint(fields=['user', 'timestamp', 'glucose_level', 'source'], name='uniq_glucose_row'),
        ]

class LibreConnection(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='libre_connection')
    email = models.CharField(max_length=200)
    # Store encrypted password/token to avoid plaintext storage; 
    password = models.CharField(max_length=200, blank=True, null=True)
    password_encrypted = models.TextField(blank=True, null=True)
    token = models.CharField(max_length=500, blank=True, null=True)
    refresh_token = models.CharField(max_length=500, blank=True, null=True)
    token_type = models.CharField(max_length=50, blank=True, null=True)
    token_expires_at = models.DateTimeField(blank=True, null=True)
    scope = models.CharField(max_length=200, blank=True, null=True)
    account_id = models.CharField(max_length=200, blank=True, null=True)
    api_endpoint = models.CharField(max_length=500, blank=True, null=True)
    connected = models.BooleanField(default=False)
    region = models.CharField(max_length=100, blank=True, null=True)
    last_synced = models.DateTimeField(blank=True, null=True)

    # authenticate: placeholder where code would reach out to LibreView/LibreLink
    # API to exchange email/password for tokens.
    def authenticate(self):
        email = self.email
        password = None
        try:

            password = self.get_password_decrypted()
        except Exception:
            pass
        if not password:
            password = self.password
        
        if not email or not password:
            return False
        base_url, token_response, auth_headers = login_with_password(email, password)
        if not (base_url and token_response and auth_headers):
            return False

        #connection metadata
        try:
            self.token = token_response.get("access_token")
            self.account_id = token_response.get("account_id")
            self.api_endpoint = base_url
            #try to derive region
            try:
                if "api-" in base_url:
                    self.region = base_url.split("//api-")[1].split(".")[0]
            except Exception:
                pass
            self.connected = True if self.token else False
            self.save(update_fields=["token", "account_id", "api_endpoint", "region", "connected"])
            return True
        except Exception:
            return False

    # helpers to set/get encrypted password using users.utils
    def set_password_encrypted(self, raw_password: str):
        try:
            from users.utils import encrypt_password
            self.password_encrypted = encrypt_password(raw_password)
            self.password = None
            self.save()
        except Exception:
            pass

    def get_password_decrypted(self):
        try:
            from users.utils import decrypt_password
            return decrypt_password(self.password_encrypted)
        except Exception:
            return None
    
    def is_token_expired(self):
        """Check if the stored token is expired."""
        if not self.token_expires_at:
            return True
        return timezone.now() >= self.token_expires_at      

    def set_token_data(self, token_response: dict):
        """Store token response from an OAuth token endpoint.

        Expected keys: access_token, refresh_token, token_type, expires_in, scope
        """
        try:
            from django.utils import timezone
            self.token = token_response.get('access_token')
            self.refresh_token = token_response.get('refresh_token')
            self.token_type = token_response.get('token_type')
            scope = token_response.get('scope')
            if isinstance(scope, list):
                scope = ' '.join(scope)
            self.scope = scope
            expires_in = token_response.get('expires_in')
            if expires_in:
                try:
                    self.token_expires_at = timezone.now() + timedelta(seconds=int(expires_in))
                except Exception:
                    self.token_expires_at = None   
            self.connected = True if self.token else False
            self.save()
        except Exception:
            pass


    def disconnect(self):
        self.connected = False
        self.token = None
        self.save()

    def __str__(self):
        return f"LibreConnection({self.user_id}, connected={self.connected})"


class GlucoseMonitor(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='glucose_monitor')
    connection = models.OneToOneField(LibreConnection, on_delete=models.SET_NULL, null=True, blank=True)
    # store recent glucose values or metadata as JSON; glucose data itself is stored in GlucoseRecord
    meta = models.JSONField(blank=True, null=True)

   
    def start_live_monitoring(self):
        if not self.connection:
            return {"error": "no_connection"}

        conn = self.connection
        if not conn.token or not conn.api_endpoint or not conn.account_id:
            ok = conn.authenticate()
            if not ok:
                return {"error": "missing or invalid token"}
        try:
            #if helper not available build manually
            account_hash = hashlib.sha256(conn.account_id.encode()).hexdigest()
            headers = {
                "authorization": f"Bearer {conn.token}",
                "account-id": account_hash,
                "accept": "application/json",
            }
            resp = requests.get(f"{conn.api_endpoint}/llu/connections", headers=headers, timeout=20)
            resp.raise_for_status()
            payload = resp.json()
        except Exception as e:
            return {"error": f"request_failed: {e}"}
        data = payload.get("data") or []
        created, fetched = 0, 0
        for item in data:
            gm = (item or {}).get("glucoseMeasurement") or {}
            if not gm:
                continue
            value = gm.get("value") or gm.get("Value")
            ts_str = gm.get("timestamp") or gm.get("Timestamp")
            trend = gm.get("TrendArrow") or gm.get("trend_arrow")
            if value is None or not ts_str:
                continue
            fetched += 1
            ts = parse_datetime(ts_str)
            if ts and timezone.is_naive(ts):
                ts = timezone.make_aware(ts, timezone=timezone.utc)
            try:
                _, was_created = GlucoseRecord.objects.get_or_create(
                    user=self.user,
                    timestamp=ts,
                    glucose_level=value,
                    source="libre_live",
                    defaults={
                        'trend_arrow': trend,
                    }
                )         
                if was_created:
                    created += 1
            except Exception:
                continue
        #update
        self.meta = {
            "last_fetch": timezone.now().isoformat(),
            "records_fetched": fetched,
            "records_created": created,
        }
        self.save(update_fields=["meta"])
        return {"fetched": fetched, "created": created}

    def fetch_latest_glucose(self):
        now = timezone.now()
        since = now - timedelta(hours=12)
        qs = (
            GlucoseRecord.objects.filter(user=self.user, timestamp__gte=since)
            .order_by("-timestamp")[:5]
        )
        results = [
            {
                "timestamp": gr.timestamp.isoformat(),
                "glucose_level": gr.glucose_level,
                "trend_arrow": gr.trend_arrow,
                "source": gr.source,
            }
            for gr in qs
        ]
        #cache summary
        self.meta = {"last_checked": now.isoformat(), "latest_levels": results}
        self.save(update_fields=["meta"])
        return results

    def __str__(self):
        return f"GlucoseMonitor(user={self.user_id})"


class Preferences(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='preferences')
    notification_enabled = models.BooleanField(default=True)
    preferred_glucose_unit = models.CharField(max_length=10, default='mg/dL')
    color_scheme = models.CharField(max_length=50, blank=True, null=True)
    language = models.CharField(max_length=20, blank=True, null=True)

    # Simple setter helper for preferred unit.
    def set_preferred_unit(self, unit: str):
        self.preferred_glucose_unit = unit
        self.save()

    def __str__(self):
        return f"Preferences(user={self.user_id})"


class Alert(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='alerts')
    alert_type = models.CharField(max_length=100)
    message = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    # send: placeholder where notification logic (push, SMS, email) 
    def send(self):
        #we return true to indicate delivered
        return True
    
    @classmethod
    def ensure_for_glucose(cls, record):
        try:
            low, high = _user_glucose_thresholds(record.user)
            level = float(record.glucose_level)
            if level < low:
                a_type = "low_glucose"
                msg = f"Low glucose {level:.0f} mg/dl"
            elif level > high:
                a_type = "high_glucose"
                msg = f"High glucose {level:.0f} mg/dl"
            else:
                return None  #in range
            since = timezone.now() - timedelta(minutes=15)
            recent = (
                cls.objects.filter(user=record.user, alert_type=a_type, timestamp__gte=since)
                .order_by("-timestamp")
                .first()
            )
            if recent:
                return None
            alert = cls.objects.create(user=record.user, alert_type=a_type, message=msg)
            alert.send()
            return alert
        except Exception:
            return None

    def __str__(self):
        return f"Alert({self.alert_type}) for {self.user_id} at {self.timestamp}"


class InsightReport(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='insight_reports')
    avg_glucose = models.FloatField(blank=True, null=True)
    most_frequent_meal_type = models.CharField(max_length=100, blank=True, null=True)
    time_of_day_with_spikes = models.CharField(max_length=100, blank=True, null=True)
    general_insights = models.TextField(blank=True, null=True)


    def generate_insights(self, days=14):
        now = timezone.now()
        since = now - timedelta(days=int(days or 14))
        try:
            low_thr, high_thr = _user_glucose_thresholds(self.user)
        except Exception:
            low_thr, high_thr = 69.0, 200.0
        
        qs = (
            GlucoseRecord.objects.filter(user=self.user, timestamp__gte=since, timestamp__lte=now).order_by("timestamp")
        )
        total = qs.count()
        if total == 0:
            empty = {
                "days": days,
                "average_glucose_mgdl": None,
                "time_in_range_pct": 0.0,
                "low_events": 0,
                "high_events": 0,
                "gmi_percent": None,
                "meal_impact_series": [],
                "most_frequent_meal_type": None,
                "time_of_day_with_spikes": None,
                "low_threshold": low_thr,
                "high_threshold": high_thr,
                "updated_at": now.isoformat(),
            }
            self.avg_glucose = None
            self.most_frequent_meal_type = None
            self.time_of_day_with_spikes = None
            self.general_insights = json.dumps(empty)
            self.save(update_fields=["avg_glucose", "most_frequent_meal_type", "time_of_day_with_spikes", "general_insights"])
            return empty

        values = list(qs.values_list("glucose_level", flat=True))
        avg_gluc = sum(values) / float(total)

        lows = qs.filter(glucose_level__lt=low_thr).count()
        highs = qs.filter(glucose_level__gt=high_thr).count()
        in_range = total - (lows + highs)
        tir_pct = round((in_range / total) * 100.0, 1)

        gmi = round(3.31 + 0.02392 * avg_gluc, 1)

        by_day = (
            qs.extra(select={"day": "date(timestamp)"})
            .values("day")
            .annotate(mean=Avg("glucose_level"))
            .order_by("day")
        )
        meal_impact_series = [
            {"day": str(row["day"]), "mean": round(float(row["mean"]), 1)}
            for row in by_day
        ]

        meals_qs = (
            FoodEntry.objects.filter(user=self.user, timestamp__gte=since, timestamp__lte=now)
            .values("meal_type")
            .annotate(n=Count("id"))
            .order_by("-n")
        )
        most_freq_meal = meals_qs[0]["meal_type"] if meals_qs else None

        highs_hours = (
            qs.filter(glucose_level__gt=high_thr)
            .extra(select={"hr": "extract(hour from timestamp)"})
            .values_list("hr", flat=True)
        )
        bucket_counts = {"Night (0-5)": 0, "Morning (6-11)": 0, "Afternoon (12-17)": 0, "Evening (18-23)": 0}
        for h in highs_hours:
            h = int(h)
            if 0 <= h <= 5:
                bucket_counts["Night (0-5)"] += 1
            elif 6 <= h <= 11:
                bucket_counts["Morning (6-11)"] += 1
            elif 12 <= h <= 17:
                bucket_counts["Afternoon (12-17)"] += 1
            elif 18 <= h <= 23:
                bucket_counts["Evening (18-23)"] += 1
        time_of_day_with_spikes = max(bucket_counts, key=bucket_counts.get) if sum(bucket_counts.values()) > 0 else None

        payload = {
            "days": days,
            "average_glucose_mgdl": round(float(avg_gluc), 1),
            "time_in_range_pct": tir_pct,
            "low_events": int(lows),
            "high_events": int(highs),
            "gmi_percent": gmi,
            "meal_impact_series": meal_impact_series,
            "most_frequent_meal_type": most_freq_meal,
            "time_of_day_with_spikes": time_of_day_with_spikes,
            "low_threshold": low_thr,
            "high_threshold": high_thr,
            "updated_at": now.isoformat(),
        }
        self.avg_glucose = payload["average_glucose_mgdl"]
        self.most_frequent_meal_type = most_freq_meal
        self.time_of_day_with_spikes = time_of_day_with_spikes
        self.general_insights = json.dumps(payload)
        self.save(update_fields=["avg_glucose", "most_frequent_meal_type", "time_of_day_with_spikes", "general_insights"]) 

        return payload

    def __str__(self):
        return f"InsightReport(user={self.user_id})"


class Recommendation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='recommendations')
    admin_id = models.CharField(max_length=200, blank=True, null=True)
    content = models.TextField()
    category = models.CharField(max_length=100, blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Recommendation({self.id}) for {self.user_id}"



class Images(models.Model):
    title = models.CharField(max_length=200)

    def __str__(self):
        return self.title


@receiver(post_save, sender=GlucoseRecord)
def _glucose_record_alert(sender, instance: GlucoseRecord, created, **kwargs):
    if not created:
        return
    try:
        Alert.ensure_for_glucose(instance)
    except Exception:
        pass