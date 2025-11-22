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
        
        # Model paths - adjust these to your actual model file locations
        self.cnn_lstm_path = "models/cnn_lstm_30min_win48.pt.best"
        self.lgb_path = "models/lgb_noSteps30min.pkl"
        self.scaler_path = "models/standard_scaler.pkl"
        self.feature_order_path = "models/lgb_feature_order.txt"
        
        # Physiological constraints
        self.MIN_GLUCOSE = 40.0   # Near-fatal level
        self.MAX_GLUCOSE = 400.0  # Severe hyperglycemia
        self.TARGET_MIN = 70.0
        self.TARGET_MAX = 180.0
        
        self._load_models()
    
    def _load_models(self):
        """Load all available prediction models"""
        try:
            # Load CNN-LSTM model if available
            if TORCH_AVAILABLE and os.path.exists(self.cnn_lstm_path):
                from core.services.ml_models import CNNLSTMModel
                self.cnn_lstm_model = CNNLSTMModel(input_dim=1)
                self.cnn_lstm_model.load_state_dict(torch.load(self.cnn_lstm_path))
                self.cnn_lstm_model.eval()
                logger.info("CNN-LSTM model loaded successfully")
            
            # Load LightGBM model if available
            if LIGHTGBM_AVAILABLE and os.path.exists(self.lgb_path):
                self.lgb_model = joblib.load(self.lgb_path)
                logger.info("LightGBM model loaded successfully")
            
            # Load scaler if available
            if os.path.exists(self.scaler_path):
                self.scaler = joblib.load(self.scaler_path)
                logger.info("Scaler loaded successfully")
            
            # Load feature order if available
            if os.path.exists(self.feature_order_path):
                with open(self.feature_order_path, 'r') as f:
                    self.feature_order = [line.strip() for line in f.readlines()]
                logger.info("Feature order loaded successfully")
            
            self.loaded = True
            logger.info("Prediction service initialized successfully")
            
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
        Improved meal impact calculation with time dynamics
        Based on standard diabetes management formulas
        """
        # Default sensitivity factors (should be personalized per user)
        if user_sensitivity is None:
            user_sensitivity = {
                'carb_ratio': 15.0,  # grams per unit of insulin (ICR)
                'correction_factor': 50.0,  # mg/dL per unit of insulin (ISF)
            }
        
        carb_ratio = user_sensitivity['carb_ratio']
        correction_factor = user_sensitivity['correction_factor']
        
        # Calculate expected glucose impact
        # Carbs raise glucose, insulin lowers it
        carb_impact = meal_carbs * (1000 / carb_ratio) / 10  # Simplified formula
        insulin_impact = meal_insulin * correction_factor
        
        net_impact = carb_impact - insulin_impact
        
        # Apply reasonable bounds to impact
        max_impact = 150  # mg/dL maximum change in 30 minutes
        return np.clip(net_impact, -max_impact, max_impact)
    
    def _generate_realistic_timeline(self, current_glucose, final_glucose, time_minutes=30):
        """Generate realistic glucose timeline with smooth transitions"""
        timeline = []
        current_time = timezone.now()
        
        # Create smooth curve using sigmoid-like progression
        for minutes in [0, 10, 20, 30]:
            # Use easing function for more realistic progression
            progress = minutes / time_minutes
            # Sigmoid-like easing for more realistic curve
            ease_factor = 1 / (1 + np.exp(-10 * (progress - 0.5)))  # Centered sigmoid
            
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
            
            glucose_records = user.glucose_records.filter(
                timestamp__range=[start_time, end_time]
            ).order_by('timestamp')
            
            if not glucose_records.exists():
                raise ValueError("Not enough glucose data for prediction")
            
            # Validate glucose readings are reasonable
            valid_records = []
            for record in glucose_records:
                if self.MIN_GLUCOSE <= record.glucose_level <= self.MAX_GLUCOSE:
                    valid_records.append(record)
                else:
                    logger.warning(f"Invalid glucose reading skipped: {record.glucose_level}")
            
            if not valid_records:
                raise ValueError("No valid glucose readings available")
            
            # Get recent food entries (last 4 hours)
            food_entries = user.food_entries.filter(
                timestamp__range=[start_time, end_time]
            ).order_by('timestamp')
            
            # Create time series data
            data = []
            current_time = start_time
            
            while current_time <= end_time:
                # Find closest glucose reading
                closest_glucose = None
                min_diff = float('inf')
                
                for record in valid_records:
                    time_diff = abs((record.timestamp - current_time).total_seconds())
                    if time_diff <= 300 and time_diff < min_diff:  # 5 min window, closest match
                        closest_glucose = record.glucose_level
                        min_diff = time_diff
                
                # Find carbs from food entries in this time window
                current_carbs = 0
                for food in food_entries:
                    if abs((food.timestamp - current_time).total_seconds()) <= 1800:  # 30 min window
                        current_carbs += food.total_carbs or 0
                
                data.append({
                    'timestamp': current_time,
                    'glucose': closest_glucose,
                    'carbs': current_carbs
                })
                
                current_time += timedelta(minutes=5)  # 5-minute intervals
            
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
            
            # Simple baseline prediction (average of last few readings)
            recent_readings = [d['glucose'] for d in user_data[-6:] if d['glucose'] is not None]
            if recent_readings:
                baseline_pred = np.mean(recent_readings)
                predictions['simple'] = self._constrain_prediction(baseline_pred)
            
            # CNN-LSTM prediction if available
            if model_type in ['cnn_lstm', 'ensemble'] and self.cnn_lstm_model and TORCH_AVAILABLE:
                try:
                    cnn_lstm_pred = self._predict_cnn_lstm(user_data)
                    predictions['cnn_lstm'] = self._constrain_prediction(cnn_lstm_pred)
                except Exception as e:
                    logger.warning(f"CNN-LSTM prediction failed: {e}")
            
            # LightGBM prediction if available
            if model_type in ['lgb', 'ensemble'] and self.lgb_model and LIGHTGBM_AVAILABLE:
                try:
                    lgb_pred = self._predict_lightgbm(user_data)
                    predictions['lgb'] = self._constrain_prediction(lgb_pred)
                except Exception as e:
                    logger.warning(f"LightGBM prediction failed: {e}")
            
            # Ensemble prediction (weighted average)
            if predictions:
                if model_type == 'ensemble' and len(predictions) > 1:
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
    
    def predict_after_meal(self, user, meal_carbs, meal_insulin=0, model_type='ensemble', lookback_minutes=240):
        """Predict glucose after a meal considering carbs and insulin"""
        try:
            # Validate inputs
            self._validate_inputs(meal_carbs, meal_insulin)
            
            # Get base prediction
            base_result = self.predict_for_user(user, model_type, lookback_minutes)
            
            if not base_result['success']:
                return base_result
            
            base_prediction = base_result['prediction']
            current_glucose = base_prediction['current_glucose']
            
            # Calculate meal impact using improved model
            meal_impact = self._calculate_meal_impact(meal_carbs, meal_insulin)
            
            # Apply meal impact to prediction
            adjusted_glucose = base_prediction['glucose_mg_dl'] + meal_impact
            adjusted_glucose = self._constrain_prediction(adjusted_glucose)
            
            # Generate realistic timeline
            timeline = self._generate_realistic_timeline(current_glucose, adjusted_glucose)
            
            # Risk assessment
            risk_level = 'normal'
            risk_message = ""
            
            if adjusted_glucose > self.TARGET_MAX:
                risk_level = 'high'
                risk_message = f"Warning: Predicted glucose ({adjusted_glucose} mg/dL) is above target range."
            elif adjusted_glucose < self.TARGET_MIN:
                risk_level = 'low' 
                risk_message = f"Warning: Predicted glucose ({adjusted_glucose} mg/dL) is below target range."
            else:
                risk_message = f"Predicted glucose ({adjusted_glucose} mg/dL) is within target range."
            
            # Add extreme value warning
            if adjusted_glucose <= self.MIN_GLUCOSE + 10 or adjusted_glucose >= self.MAX_GLUCOSE - 10:
                risk_level = 'extreme'
                risk_message = f"CRITICAL: Predicted glucose ({adjusted_glucose} mg/dL) is at dangerous levels!"
            
            return {
                'success': True,
                'prediction': {
                    'glucose_mg_dl': round(adjusted_glucose, 1),
                    'time_horizon_minutes': 30,
                    'predictions_by_model': base_prediction['predictions_by_model'],
                    'risk_assessment': {
                        'level': risk_level,
                        'message': risk_message
                    },
                    'current_glucose': current_glucose,
                    'change': round(adjusted_glucose - current_glucose, 1),
                    'timeline': timeline,
                    'meal_impact': round(meal_impact, 1)
                },
                'meal_info': {
                    'carbs_g': meal_carbs,
                    'insulin_units': meal_insulin
                },
                'metadata': base_result['metadata']
            }
            
        except Exception as e:
            logger.error(f"Meal prediction failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def _predict_cnn_lstm(self, user_data):
        """CNN-LSTM model prediction"""
        # This would integrate with your existing CNN_LSTM_Predict.py
        # For now, return a simple prediction
        recent_readings = [d['glucose'] for d in user_data[-10:] if d['glucose'] is not None]
        return np.mean(recent_readings) if recent_readings else 120
    
    def _predict_lightgbm(self, user_data):
        """LightGBM model prediction"""
        # This would integrate with your existing lgb_predicts.py
        # For now, return a simple prediction
        recent_readings = [d['glucose'] for d in user_data[-10:] if d['glucose'] is not None]
        return np.mean(recent_readings) if recent_readings else 120
    
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