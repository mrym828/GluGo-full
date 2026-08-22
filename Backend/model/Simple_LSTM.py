import pandas as pd
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from sklearn.metrics import mean_absolute_error, mean_squared_error
import matplotlib.pyplot as plt
import os
import math

# 1. Load Data
DATA_FILE = "Processed_Data/noSteps_features30min.parquet"
df = pd.read_parquet(DATA_FILE)
# Split train/test by patient
unique_patients = df["patient_id"].unique()
x = round(len(unique_patients) * 0.2)
np.random.seed(42)
test_patients = np.random.choice(unique_patients, size=x, replace=False)
train_patients = [p for p in unique_patients if p not in test_patients]

train_df = df[df["patient_id"].isin(train_patients)]
test_df = df[df["patient_id"].isin(test_patients)]

# Prepare features
target_col = "target_glucose"
exclude_cols = ["timestamp", "patient_id", target_col]
features = [c for c in df.columns if c not in exclude_cols]

# 2. Sequence Dataset
SEQ_LEN = 6  # 6 × 5min = 30min history


class SeqDataset(Dataset):
    def __init__(self, df):
        self.df = df.sort_values(["patient_id", "timestamp"])
        self.X = self.df[features].values
        self.y = self.df[target_col].values

    def __len__(self):
        return len(self.df) - SEQ_LEN

    def __getitem__(self, idx):
        X_seq = self.X[idx : idx + SEQ_LEN]  # shape (6, num_features)
        y_val = self.y[idx + SEQ_LEN]  # predict the step after the window
        return torch.tensor(X_seq, dtype=torch.float32), torch.tensor(
            y_val, dtype=torch.float32
        )


train_data = SeqDataset(train_df)
test_data = SeqDataset(test_df)

train_loader = DataLoader(train_data, batch_size=64, shuffle=True)
test_loader = DataLoader(test_data, batch_size=64, shuffle=False)


# 3. LSTM Model
class LSTMModel(nn.Module):
    def __init__(self, input_dim, hidden_dim=64, num_layers=2):
        super().__init__()
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers, batch_first=True)
        self.fc = nn.Linear(hidden_dim, 1)

    def forward(self, x):
        out, _ = self.lstm(x)
        out = out[:, -1, :]  # last time step
        out = self.fc(out)
        return out


model = LSTMModel(input_dim=len(features))
criterion = nn.MSELoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

# 4. Train
EPOCHS = 20
model.train()

for epoch in range(EPOCHS):
    epoch_loss = 0
    for X_batch, y_batch in train_loader:
        optimizer.zero_grad()
        preds = model(X_batch).squeeze()
        loss = criterion(preds, y_batch)
        loss.backward()
        optimizer.step()
        epoch_loss += loss.item()

    print(f"Epoch {epoch + 1}/{EPOCHS}, Loss: {epoch_loss / len(train_loader):.4f}")

# 5. Evaluate
model.eval()
all_preds, all_true = [], []

with torch.no_grad():
    for X_batch, y_batch in test_loader:
        preds = model(X_batch).squeeze()
        all_preds.extend(preds.numpy())
        all_true.extend(y_batch.numpy())

mae = mean_absolute_error(all_true, all_preds)
rmse = math.sqrt(mean_squared_error(all_true, all_preds))
y_true = np.array(all_true)
y_preds = np.array(all_preds)
mape = np.mean(np.abs((y_true - y_preds) / y_true)) * 100
print(f"\nTest MAE: {mae:.2f}, Test RMSE: {rmse:.2f}, MAPE: {mape:.2f}%")

# 6. Visualization (1 Patient)
test_df_sorted = test_df.sort_values("timestamp").reset_index(drop=True)
comparison_df = test_df_sorted.iloc[SEQ_LEN:].copy()
comparison_df["predicted_glucose"] = all_preds

pid = test_patients[0]
patient_plot = comparison_df[comparison_df["patient_id"] == pid]

plt.figure(figsize=(12, 5))
plt.plot(
    patient_plot["timestamp"],
    patient_plot["target_glucose"],
    label="Actual",
    linewidth=2,
)
plt.plot(
    patient_plot["timestamp"],
    patient_plot["predicted_glucose"],
    label="Predicted",
    linewidth=2,
    alpha=0.8,
)
plt.title(f"LSTM Forecast – Patient {pid} (30 min)")
plt.xlabel("Time")
plt.ylabel("Glucose mg/dL")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()

# 7. Save the LSTM model
os.makedirs("models", exist_ok=True)
torch.save(model.state_dict(), "models/lstm_30min_win6.pt")
print("\nModel saved: models/lstm_30min_win6.pt")
