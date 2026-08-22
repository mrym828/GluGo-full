import os
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from django.utils import timezone
import logging
import joblib
import torch
import tempfile
from django.core.files.base import ContentFile

logger = logging.getLogger(__name__)

# Check dependencies
try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False

try:
    import lightgbm as lgb
    LIGHTGBM_AVAILABLE = True
except ImportError:
    LIGHTGBM_AVAILABLE = False

class GlucosePredictionService:
    def __init__(self):
        self.loaded = False
        self.cnn_lstm_model = None
        self.lgb_model = None
        self.scaler = None
        self.feature_order = None

        # Model paths - use absolute paths from Django settings or BASE_DIR
        from django.conf import settings
        base_dir = getattr(settings, 'BASE_DIR', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        models_dir = os.path.join(base_dir, 'model')

        self.cnn_lstm_path = os.path.join(models_dir, "cnn_lstm_30min_win48.pt.best")
        self.lgb_path = os.path.join(models_dir, "lgb_noSteps30min.pkl")
        self.scaler_path = os.path.join(models_dir, "standard_scaler.pkl")
        self.feature_order_path = os.path.join(models_dir, "lgb_feature_order.txt")
        
        # Physiological constraints
        self.MIN_GLUCOSE = 40.0   # Near-fatal level
        self.MAX_GLUCOSE = 400.0  # Severe hyperglycemia
        self.TARGET_MIN = 70.0
        self.TARGET_MAX = 180.0
        
        self._load_models()
    
    def _load_models(self):
        """Load all available prediction models"""
        try:
            logger.info(f"Loading models from: {self.cnn_lstm_path}")
            # Load CNN-LSTM model if available
            if TORCH_AVAILABLE and os.path.exists(self.cnn_lstm_path):
                try:
                    from core.services.ml_models import CNNLSTMModel
                    self.cnn_lstm_model = CNNLSTMModel(input_dim=1)
                    self.cnn_lstm_model.load_state_dict(torch.load(self.cnn_lstm_path, map_location='cpu'))
                    self.cnn_lstm_model.eval()
                    logger.info("CNN-LSTM model loaded successfully")
                except Exception as e:
                    logger.error(f"Failed to load CNN-LSTM model: {e}")
                    self.cnn_lstm_model = None

            # Load LightGBM model if available
            if LIGHTGBM_AVAILABLE and os.path.exists(self.lgb_path):
                try:
                    self.lgb_model = joblib.load(self.lgb_path)
                    logger.info("LightGBM model loaded successfully")
                except Exception as e:
                    logger.error(f"Failed to load LightGBM model: {e}")
                    self.lgb_model = None
            # Load scaler if available
            if os.path.exists(self.scaler_path):
                try:
                    self.scaler = joblib.load(self.scaler_path)
                    logger.info("Scaler loaded successfully")
                except Exception as e:
                    logger.error(f"Failed to load scaler: {e}")
                    self.scaler = None
                    
            # Load feature order if available
            if os.path.exists(self.feature_order_path):
                try: 
                    with open(self.feature_order_path, 'r') as f:
                        self.feature_order = [line.strip() for line in f.readlines()]
                    logger.info("Feature order loaded successfully")
                except Exception as e:
                    logger.error(f"Failed to load feature order: {e}")
                    self.feature_order = None

            loaded_models = []
            if self.cnn_lstm_model : loaded_models.append('CNN-LSTM')
            if self.lgb_model : loaded_models.append('LightGBM')

            logger.info(f"Successfully loaded models: {loaded_models}")
            self.loaded = len(loaded_models) > 0
            
        except Exception as e:
            logger.error(f"Error loading prediction models: {e}")
            self.loaded = False
    
    def _constrain_prediction(self, glucose_value):
        """Apply physiological constraints to predictions"""
        return np.clip(glucose_value, self.MIN_GLUCOSE, self.MAX_GLUCOSE)
    
    def _validate_inputs(self, meal_carbs, meal_insulin):
        """Validate input parameters for reasonable ranges"""
        if meal_carbs < 0 or meal_carbs > 200:  # Reasonable carb range
            raise ValueError(f"Invalid carb amount: {meal_carbs}g")
        if meal_insulin < 0 or meal_insulin > 50:  # Reasonable insulin range
            raise ValueError(f"Invalid insulin amount: {meal_insulin} units")
        return True
    
    def _calculate_meal_impact(self, meal_carbs, meal_insulin, user_sensitivity=None):
        """
        Physiological model for meal impact prediction
        Based on carb absorption and insulin action curves
        """
        # Default sensitivity factors (should be personalized per user)
        if user_sensitivity is None:
            user_sensitivity = {
                'carb_ratio': 15.0,  # grams per unit of insulin (ICR)
                'correction_factor': 50.0,  # mg/dL per unit of insulin (ISF)
                'carb_sensitivity': 5.0,  # mg/dL per gram of carbs
            }
        
        carb_sensitivity = user_sensitivity.get('carb_sensitivity', 5.0)
        correction_factor = user_sensitivity.get('correction_factor', 50.0)
        
        # Time horizon is 30 minutes
        time_minutes = 30
        time_fraction = time_minutes / 120.0  # 2-hour absorption window
        
        # Carb absorption curve (sigmoid-like, peaks at 60-90 min)
        # At 30 min: ~35-40% of total carb effect
        carb_absorption_rate = self._carb_absorption_curve(time_fraction)
        
        # Insulin action curve (peaks at 60-90 min for rapid-acting)
        # At 30 min: ~25-30% of total insulin effect
        insulin_action_rate = self._insulin_action_curve(time_fraction)
        
        # Calculate impacts
        total_carb_impact = meal_carbs * carb_sensitivity
        carb_impact_at_time = total_carb_impact * carb_absorption_rate
        
        total_insulin_impact = meal_insulin * correction_factor
        insulin_impact_at_time = total_insulin_impact * insulin_action_rate
        
        # Net impact
        net_impact = carb_impact_at_time - insulin_impact_at_time
        
        # Apply physiological bounds
        max_impact = 150   # Maximum rise in 30 min
        min_impact = -100  # Maximum drop in 30 min
        
        return np.clip(net_impact, min_impact, max_impact)
    
    def _carb_absorption_curve(self, time_fraction):
        """
        Carb absorption follows a sigmoid curve
        Peaks around 60-90 minutes (0.5-0.75 time_fraction)
        """
        # Sigmoid function adjusted for carb absorption
        # At t=0.25 (30min): ~0.35-0.40
        # At t=0.50 (60min): ~0.65-0.70
        # At t=1.0 (120min): ~0.95
        k = 6.0  # Steepness
        midpoint = 0.5
        return 1 / (1 + np.exp(-k * (time_fraction - midpoint)))
    
    def _insulin_action_curve(self, time_fraction):
        """
        Insulin action curve for rapid-acting insulin
        Starts at ~15 min, peaks at 60-90 min, lasts 3-5 hours
        Using a skewed bell curve
        """
        # At t=0.25 (30min): ~0.25-0.30
        # At t=0.50 (60min): ~0.60-0.65
        # At t=0.75 (90min): ~0.80-0.85
        if time_fraction < 0.125:  # First 15 min - minimal effect
            return time_fraction * 2  # Linear ramp-up
        else:
            # Sigmoid after onset
            k = 5.0
            midpoint = 0.6
            return 1 / (1 + np.exp(-k * (time_fraction - midpoint)))
    
    def _generate_realistic_timeline(self, current_glucose, final_glucose, time_minutes=30):
        """Generate realistic glucose timeline with smooth transitions"""
        timeline = []
        current_time = timezone.now()
        
        # Create smooth curve using sigmoid-like progression
        for minutes in [0, 10, 20, 30]:
            # Use easing function for more realistic progression
            progress = minutes / time_minutes
            # Sigmoid-like easing for more realistic curve
            if progress <= 0.5:
                ease_factor = 2 * (progress ** 2)
            else:
                ease_factor = 1 - 2 * ((1 - progress) ** 2)
            
            predicted_glucose = current_glucose + (final_glucose - current_glucose) * ease_factor
            predicted_glucose = self._constrain_prediction(predicted_glucose)
            
            timeline.append({
                'minutes': minutes,
                'glucose': round(float(predicted_glucose), 1),
                'timestamp': (current_time + timedelta(minutes=minutes)).isoformat()
            })
        
        return timeline

    def prepare_user_data(self, user, lookback_minutes=240):
        """Prepare user data for prediction"""
        try:
            # Get recent glucose records
            end_time = timezone.now()
            start_time = end_time - timedelta(minutes=lookback_minutes)
            
            logger.info(f"Looking for glucose data between {start_time} and {end_time}")

            glucose_records = user.glucose_records.filter(
                timestamp__range=[start_time, end_time]
            ).order_by('timestamp')

            logger.info(f"Found {glucose_records.count()} glucose records in time range")

            if not glucose_records.exists():
                logger.warning("No recent glucose data found, using latest available")
                glucose_records = user.glucose_records.order_by('-timestamp')[:48]
                if not glucose_records.exists():
                    raise ValueError("No glucose data available for prediction")            
            
            valid_records = []
            for record in glucose_records:
                if self.MIN_GLUCOSE <= record.glucose_level <= self.MAX_GLUCOSE:
                    valid_records.append(record)
                else:
                    logger.warning(f"Invalid glucose reading skipped: {record.glucose_level}")
            
            if not valid_records:
                raise ValueError("No valid glucose readings available")
            
            logger.info(f"Using {len(valid_records)} valid glucose records")

            data = []
            current_time = start_time
            
            while current_time <= end_time:
                # Find closest glucose reading
                closest_glucose = None
                min_diff = float('inf')
                
                for record in valid_records:
                    time_diff = abs((record.timestamp - current_time).total_seconds())
                    if time_diff <= 600 and time_diff < min_diff:  # 5 min window, closest match
                        closest_glucose = record.glucose_level
                        min_diff = time_diff
                
                if closest_glucose is None and data:
                # Use last known value if available
                    closest_glucose = data[-1]['glucose']
                
                data.append({
                    'timestamp': current_time,
                    'glucose': closest_glucose,
                    'carbs': 0  # Default, can be updated if food data available
                })
                
                current_time += timedelta(minutes=5)

                while data and data[0]['glucose'] is None:
                    data.pop(0)
                
                logger.info(f"Prepared {len(data)} data points, {len([d for d in data if d['glucose'] is not None])} with glucose values")
            return data
            
        except Exception as e:
            logger.error(f"Error preparing user data: {e}")
            raise
    
    def predict_for_user(self, user, model_type='ensemble', lookback_minutes=240):
        """Predict glucose 30 minutes ahead for a user"""
        try:
            user_data = self.prepare_user_data(user, lookback_minutes)
            
            if not user_data:
                raise ValueError("No data available for prediction")
            
            # Get current glucose (most recent non-null value)
            current_glucose = None
            for data_point in reversed(user_data):
                if data_point['glucose'] is not None:
                    current_glucose = data_point['glucose']
                    break
            
            if current_glucose is None:
                raise ValueError("No recent glucose readings available")
            
            # Validate current glucose
            current_glucose = self._constrain_prediction(current_glucose)
            
            predictions = {}

            predictions['simple'] = current_glucose
            
            if model_type in ['cnn_lstm', 'ensemble'] and self.cnn_lstm_model is not None and TORCH_AVAILABLE:
                try:
                    cnn_lstm_pred = self._predict_cnn_lstm(user_data)
                    if cnn_lstm_pred is not None:
                        predictions['cnn_lstm'] = self._constrain_prediction(cnn_lstm_pred)
                        logger.info(f"CNN-LSTM prediction: {predictions['cnn_lstm']}")
                except Exception as e:
                    logger.warning(f"CNN-LSTM prediction failed: {e}")
           
            # LightGBM prediction if available
            if model_type in ['lgb', 'ensemble'] and self.lgb_model is not None and LIGHTGBM_AVAILABLE:
                try:
                    lgb_pred = self._predict_lightgbm(user_data)
                    if lgb_pred is not None:
                        predictions['lgb'] = self._constrain_prediction(lgb_pred)
                        logger.info(f"LightGBM prediction: {predictions['lgb']}")
                except Exception as e:
                    logger.warning(f"LightGBM prediction failed: {e}")
            
            logger.info(f"Available predictions: {list(predictions.keys())}")
                
            # Ensemble prediction (weighted average)
            if len(predictions) > 1:
                if model_type == 'ensemble':
                    # Weight predictions based on model confidence
                    weights = {
                        'cnn_lstm': 0.4,
                        'lgb': 0.4,
                        'simple': 0.2
                    }
                    
                    final_pred = 0
                    total_weight = 0
                    
                    for model, pred in predictions.items():
                        if model in weights:
                            final_pred += pred * weights[model]
                            total_weight += weights[model]
                    
                    if total_weight > 0:
                        final_prediction = final_pred / total_weight
                    else:
                        final_prediction = predictions.get('simple', current_glucose)
                else:
                    # Use the preferred model or fallback
                    final_prediction = predictions.get(model_type, predictions.get('simple', current_glucose))
            else:
                final_prediction = current_glucose  # Fallback to current reading
            
            # Apply final constraints
            final_prediction = self._constrain_prediction(final_prediction)
            
            return {
                'success': True,
                'prediction': {
                    'glucose_mg_dl': round(float(final_prediction), 1),
                    'time_horizon_minutes': 30,
                    'predictions_by_model': predictions,
                    'current_glucose': current_glucose,
                    'change': round(float(final_prediction - current_glucose), 1),
                    'timestamp': timezone.now().isoformat()
                },
                'metadata': {
                    'model_used': model_type,
                    'available_models': list(predictions.keys()),
                    'data_points_used': len([d for d in user_data if d['glucose'] is not None])
                }
            }
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            return {
                'success': False,
                'error': str(e),
                'prediction': None
            }
    
    def predict_after_meal(self, user, meal_carbs, meal_insulin=0, model_type='physiological', lookback_minutes=240):
        """
        Predict glucose after a meal considering carbs and insulin
        Uses physiological model for prospective meal scenarios
        """
        try:
            # Validate inputs
            self._validate_inputs(meal_carbs, meal_insulin)

            # Get current glucose level
            current_glucose = None
            try:
                latest_record = user.glucose_records.order_by('-timestamp').first()
                if latest_record:
                    current_glucose = float(latest_record.glucose_level)
            except Exception as e:
                logger.error(f"Failed to get current glucose: {e}")
            
            if current_glucose is None or current_glucose <= 0:
                return {
                    'success': False,
                    'error': 'No recent glucose readings available'
                }

            # Get user's sensitivity parameters from profile
            user_sensitivity = {
                'carb_ratio': 15.0,
                'correction_factor': 50.0,
                'carb_sensitivity': 5.0,
            }
            
            if hasattr(user, 'insulin_to_carb_ratio') and user.insulin_to_carb_ratio:
                user_sensitivity['carb_ratio'] = float(user.insulin_to_carb_ratio)
            
            if hasattr(user, 'correction_factor') and user.correction_factor:
                user_sensitivity['correction_factor'] = float(user.correction_factor)
            
            # Calculate meal impact using physiological model
            meal_impact = self._calculate_meal_impact(meal_carbs, meal_insulin, user_sensitivity)
            
            # Predict final glucose
            predicted_glucose = current_glucose + meal_impact
            predicted_glucose = self._constrain_prediction(predicted_glucose)
            
            # Generate realistic timeline
            timeline = self._generate_realistic_timeline(current_glucose, predicted_glucose)
            
            # Risk assessment
            risk_level = 'normal'
            risk_message = ""
            
            if predicted_glucose > self.TARGET_MAX:
                risk_level = 'high'
                risk_message = f"Warning: Predicted glucose ({predicted_glucose:.1f} mg/dL) is above target range."
            elif predicted_glucose < self.TARGET_MIN:
                risk_level = 'low' 
                risk_message = f"Warning: Predicted glucose ({predicted_glucose:.1f} mg/dL) is below target range."
            else:
                risk_message = f"Predicted glucose ({predicted_glucose:.1f} mg/dL) is within target range."
            
            # Add extreme value warning
            if predicted_glucose <= self.MIN_GLUCOSE + 10 or predicted_glucose >= self.MAX_GLUCOSE - 10:
                risk_level = 'extreme'
                risk_message = f"CRITICAL: Predicted glucose ({predicted_glucose:.1f} mg/dL) is at dangerous levels!"
            
            return {
                'success': True,
                'prediction': {
                    'glucose_mg_dl': round(predicted_glucose, 1),
                    'time_horizon_minutes': 30,
                    'predictions_by_model': {'physiological': round(predicted_glucose, 1)},
                    'risk_assessment': {
                        'level': risk_level,
                        'message': risk_message
                    },
                    'current_glucose': current_glucose,
                    'change': round(predicted_glucose - current_glucose, 1),
                    'timeline': timeline,
                    'meal_impact': round(meal_impact, 1)
                },
                'meal_info': {
                    'carbs_g': meal_carbs,
                    'insulin_units': meal_insulin
                },
                'metadata': {
                    'model_used': 'physiological',
                    'user_sensitivity': user_sensitivity
                }
            }
            
        except Exception as e:
            logger.error(f"Meal prediction failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    
    def _predict_cnn_lstm(self, user_data):
        """CNN-LSTM model prediction using loaded model"""
        try:
            # Prepare sequence of 48 glucose readings (last 4 hours at 5-min intervals)
            glucose_sequence = []
            for data_point in user_data[-48:]:
                if data_point['glucose'] is not None:
                    glucose_sequence.append(data_point['glucose'])
                else:
                    # Fill missing values with interpolation or last known value
                    if glucose_sequence:
                        glucose_sequence.append(glucose_sequence[-1])
                    else:
                        glucose_sequence.append(120.0)  # Default value

            # Pad sequence if needed
            while len(glucose_sequence) < 48:
                if glucose_sequence:
                    glucose_sequence.insert(0, glucose_sequence[0])
                else:
                    glucose_sequence.append(120.0)

            # Take last 48 readings
            glucose_sequence = glucose_sequence[-48:]

            # Normalize using scaler if available
            if self.scaler:
                glucose_array = np.array(glucose_sequence).reshape(-1, 1)
                glucose_normalized = self.scaler.transform(glucose_array).flatten()
            else:
                # Simple normalization
                glucose_normalized = (np.array(glucose_sequence) - 120.0) / 50.0

            # Prepare tensor for model
            x_tensor = torch.FloatTensor(glucose_normalized).unsqueeze(0).unsqueeze(-1)  # (1, 48, 1)

            # Make prediction
            with torch.no_grad():
                prediction = self.cnn_lstm_model(x_tensor)
                predicted_value = prediction.item()

            # Denormalize prediction
            if self.scaler:
                predicted_glucose = self.scaler.inverse_transform([[predicted_value]])[0][0]
            else:
                predicted_glucose = (predicted_value * 50.0) + 120.0

            return float(predicted_glucose)

        except Exception as e:
            logger.error(f"CNN-LSTM prediction failed: {e}")
            # Fallback to simple average
            recent_readings = [d['glucose'] for d in user_data[-10:] if d['glucose'] is not None]
            return np.mean(recent_readings) if recent_readings else 120.0

    def _predict_lightgbm(self, user_data):
        """LightGBM model prediction using loaded model"""
        try:
            # Extract features from user data
            glucose_values = [d['glucose'] for d in user_data if d['glucose'] is not None]
            carb_values = [d['carbs'] for d in user_data if d['carbs'] > 0]

            if not glucose_values:
                return 120.0

            # Create feature vector based on expected features
            features = {
                'glucose_mean': np.mean(glucose_values[-12:]),  # Last hour average
                'glucose_std': np.std(glucose_values[-12:]) if len(glucose_values) >= 12 else 0,
                'glucose_min': np.min(glucose_values[-12:]) if len(glucose_values) >= 12 else glucose_values[-1],
                'glucose_max': np.max(glucose_values[-12:]) if len(glucose_values) >= 12 else glucose_values[-1],
                'glucose_current': glucose_values[-1],
                'glucose_prev_5min': glucose_values[-2] if len(glucose_values) >= 2 else glucose_values[-1],
                'glucose_prev_10min': glucose_values[-3] if len(glucose_values) >= 3 else glucose_values[-1],
                'glucose_trend': glucose_values[-1] - glucose_values[-6] if len(glucose_values) >= 6 else 0,
                'carbs_last_30min': sum(carb_values[-6:]) if carb_values else 0,
                'carbs_last_60min': sum(carb_values[-12:]) if carb_values else 0,
            }

            # If feature order file is loaded, use it to create feature array
            if self.feature_order:
                feature_array = []
                for feature_name in self.feature_order:
                    feature_array.append(features.get(feature_name, 0))
                feature_array = np.array([feature_array])
            else:
                # Use features in default order
                feature_array = np.array([[
                    features['glucose_current'],
                    features['glucose_mean'],
                    features['glucose_std'],
                    features['glucose_min'],
                    features['glucose_max'],
                    features['glucose_prev_5min'],
                    features['glucose_prev_10min'],
                    features['glucose_trend'],
                    features['carbs_last_30min'],
                    features['carbs_last_60min'],
                ]])

            # Make prediction
            prediction = self.lgb_model.predict(feature_array)
            return float(prediction[0])

        except Exception as e:
            logger.error(f"LightGBM prediction failed: {e}")
            # Fallback to simple average
            recent_readings = [d['glucose'] for d in user_data[-10:] if d['glucose'] is not None]
            return np.mean(recent_readings) if recent_readings else 120.0
    
    def _get_risk_message(self, risk_level, glucose):
        messages = {
            'low': f"Warning: Predicted glucose ({glucose} mg/dL) is below target range.",
            'normal': f"Predicted glucose ({glucose} mg/dL) is within target range.",
            'high': f"Warning: Predicted glucose ({glucose} mg/dL) is above target range.",
            'extreme': f"CRITICAL: Predicted glucose ({glucose} mg/dL) is at dangerous levels!"
        }
        return messages.get(risk_level, "Glucose prediction available.")

# Global instance
prediction_service = GlucosePredictionService()