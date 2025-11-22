import pandas as pd
import numpy as np


def add_lag_rolling(df, col, lags=[1, 2, 3, 6, 12], rolls=[3, 6, 12]):
    for lag in lags:
        df[f"{col}_lag{lag}"] = df[col].shift(lag)
    for w in rolls:
        df[f"{col}_rollmean{w}"] = df[col].rolling(w).mean()
        df[f"{col}_rollstd{w}"] = df[col].rolling(w).std()
    df[f"{col}_diff1"] = df[col].diff(1)
    return df


def compute_decay_feature(df, value_col, tau, new_col):
    vals = df[value_col].fillna(0).values
    out = np.zeros_like(vals, dtype=float)
    for t in range(1, len(vals)):
        out[t] = vals[t] + out[t - 1] * np.exp(-1 / tau)
    df[new_col] = out
    return df


def create_features_from_csv(file_path):
    df = pd.read_csv(file_path, parse_dates=["timestamp"])
    df = df.sort_values("timestamp").reset_index(drop=True)
    df["patient_id"] = 0

    # Time-based
    df["hour"] = df["timestamp"].dt.hour
    df["minute"] = df["timestamp"].dt.minute
    df["dayofweek"] = df["timestamp"].dt.dayofweek
    df["hour_sin"] = np.sin(2 * np.pi * df["hour"] / 24)
    df["hour_cos"] = np.cos(2 * np.pi * df["hour"] / 24)

    # Lag/Rolling
    for c in ["glucose"]:
        if c in df.columns:
            df = add_lag_rolling(df, c)

    # IOB/COB
    if "insulin" in df.columns:
        df = compute_decay_feature(df, "insulin", tau=48, new_col="IOB")
    if "carbs" in df.columns:
        df = compute_decay_feature(df, "carbs", tau=24, new_col="COB")

    df = df.dropna().reset_index(drop=True)
    return df
