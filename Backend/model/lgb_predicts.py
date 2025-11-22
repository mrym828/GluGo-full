import os
import joblib
import pandas as pd
import numpy as np
from feature_utils import create_features_from_csv

# Configuration
MODEL_PATH = "lgb_noSteps30min.pkl"
FEATURE_ORDER_FILE = "lgb_feature_order.txt"  #  helper file


def predict_next_glucoselgb(csv_path: str):
    """
    Given a CSV with ['timestamp', 'glucose', 'insulin', 'carbs'],
    this function:
      1. Generates engineered features via feature_utils.py
      2. Matches feature order from training
      3. Loads LightGBM model
      4. Returns predicted glucose 30 min ahead
    """

    # Check paths
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Trained LightGBM model not found at {MODEL_PATH}")

    # Generate features
    df = create_features_from_csv(csv_path)
    df = df.sort_values("timestamp").reset_index(drop=True)

    # Prepare features
    target_col = "target_glucose"
    exclude_cols = ["timestamp", "patient_id", target_col]
    features = [c for c in df.columns if c not in exclude_cols]

    # feature order
    if os.path.exists(FEATURE_ORDER_FILE):
        with open(FEATURE_ORDER_FILE, "r") as f:
            saved_features = [line.strip() for line in f.readlines()]
        # align new df columns to training order
        missing = [f for f in saved_features if f not in df.columns]
        if missing:
            raise ValueError(f"Missing expected features: {missing}")
        df = df[saved_features]
        features = saved_features

    # Load trained model
    model = joblib.load(MODEL_PATH)

    # Select the most recent valid row for prediction
    if len(df) == 0:
        raise ValueError("No data rows after feature creation")
    X_input = df[features].iloc[[-1]]  # latest observation

    # Predict
    pred = model.predict(X_input)[0]
    print(f"Predicted glucose (30 min ahead) using Lgb: {pred:.2f} mg/dL")
    return pred
