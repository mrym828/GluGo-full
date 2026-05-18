import pandas as pd
import numpy as np
import os
from catboost import CatBoostRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error
import matplotlib.pyplot as plt
import joblib

DATA_FILE = "Processed_Data/noSteps_features30min.parquet"
OUTPUT_FILE = "models/catboost_noSteps30min.pkl"
df = pd.read_parquet(DATA_FILE)

# split into train/test per patient
unique_patients = df["patient_id"].unique()
np.random.seed(42)
test_patients = np.random.choice(unique_patients, size=13, replace=False)
train_patients = [p for p in unique_patients if p not in test_patients]

train_df = df[df["patient_id"].isin(train_patients)]
test_df = df[df["patient_id"].isin(test_patients)]

# prepare features and labels
target_col = "target_glucose"
exclude_cols = ["timestamp", "patient_id", target_col]
features = [c for c in df.columns if c not in exclude_cols]

X_train, y_train = train_df[features], train_df[target_col]
X_test, y_test = test_df[features], test_df[target_col]

# train CatBoost
model = CatBoostRegressor(
    iterations=1000,
    learning_rate=0.05,
    depth=8,
    subsample=0.8,
    colsample_bylevel=0.8,
    random_seed=42,
    loss_function="MAE",
    eval_metric="MAE",
    early_stopping_rounds=50,
    verbose=100,
)

model.fit(X_train, y_train, eval_set=(X_test, y_test))

# Evaluate
y_pred = model.predict(X_test)
mae = mean_absolute_error(y_test, y_pred)
mse = mean_squared_error(y_test, y_pred)
rmse = np.sqrt(mse)
print(f"MAE: {mae:.2f}, RMSE: {rmse:.2f}")

# compare predicted to actual:
comparison_df = test_df[["timestamp", "patient_id", "glucose", "target_glucose"]].copy()
comparison_df["predicted_glucose"] = y_pred
comparison_df["error"] = (
    comparison_df["predicted_glucose"] - comparison_df["target_glucose"]
)

# visualize
pid = test_patients[0]
patient_df = comparison_df[comparison_df["patient_id"] == pid].sort_values("timestamp")

plt.figure(figsize=(12, 5))
plt.plot(
    patient_df["timestamp"],
    patient_df["target_glucose"],
    label="Actual (future)",
    linewidth=2,
)
plt.plot(
    patient_df["timestamp"],
    patient_df["predicted_glucose"],
    label="Predicted",
    linewidth=2,
    alpha=0.8,
)
plt.title(f"Patient {pid} – Glucose Forecast (30 min ahead, CatBoost)")
plt.xlabel("Timestamp")
plt.ylabel("Glucose (mg/dL)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()

# save model
os.makedirs("models", exist_ok=True)
joblib.dump(model, OUTPUT_FILE)
