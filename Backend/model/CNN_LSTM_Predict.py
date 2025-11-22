import os
import torch
import joblib
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from torch import nn
from feature_utils import create_features_from_csv

# Configuration
MODEL_PATH = "cnn_lstm_30min_win48.pt.best"
SCALER_PATH = "standard_scaler.pkl"
SEQ_LEN = 48  # 2 hours history (5 min interval × 48)
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# CNN-LSTM Model Definition
class CNNLSTMModel(nn.Module):
    def __init__(
        self,
        input_dim,
        conv_channels=64,
        conv_kernel_size=3,
        conv_layers=2,
        lstm_hidden=128,
        lstm_layers=3,
        dropout=0.3,
    ):
        super().__init__()
        convs = []
        in_ch = input_dim
        for _ in range(conv_layers):
            convs.append(
                nn.Conv1d(
                    in_channels=in_ch,
                    out_channels=conv_channels,
                    kernel_size=conv_kernel_size,
                    padding=conv_kernel_size // 2,
                )
            )
            convs.append(nn.ReLU())
            convs.append(nn.BatchNorm1d(conv_channels))
            convs.append(nn.Dropout(dropout))
            in_ch = conv_channels
        self.conv = nn.Sequential(*convs)

        self.lstm = nn.LSTM(
            input_size=conv_channels,
            hidden_size=lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        self.fc = nn.Linear(lstm_hidden, 1)
        self._init_weights()

    def _init_weights(self):
        for name, param in self.named_parameters():
            if "weight" in name and param.dim() > 1:
                nn.init.xavier_uniform_(param)
            elif "bias" in name:
                nn.init.constant_(param, 0.0)

    def forward(self, x):
        x_conv_in = x.transpose(1, 2)  # (batch, input_dim, seq_len)
        x_conv = self.conv(x_conv_in)
        x_seq = x_conv.transpose(1, 2)  # (batch, seq_len, conv_channels)
        out, _ = self.lstm(x_seq)
        out = out[:, -1, :]  # last timestep
        out = self.fc(out).squeeze(-1)
        return out


# Prediction Function
def predict_next_glucose(csv_path: str):
    """
    Given a CSV file with ['timestamp', 'glucose', 'insulin', 'carbs'],
    this function:
        1. Generates engineered features (via feature_utils)
        2. Scales them using the saved StandardScaler
        3. Builds the last 48-step input window
        4. Returns a single predicted glucose value (30 min ahead)
    """
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Model not found at {MODEL_PATH}")
    if not os.path.exists(SCALER_PATH):
        raise FileNotFoundError(f"Scaler not found at {SCALER_PATH}")

    # Generate features
    df = create_features_from_csv(csv_path)  # function from feature_utils.py
    df = df.sort_values("timestamp").reset_index(drop=True)

    # Load scaler and scale features
    scaler = joblib.load(SCALER_PATH)
    target_col = "target_glucose"
    exclude_cols = ["timestamp", "patient_id", target_col]
    features = [c for c in df.columns if c not in exclude_cols]

    # scale numeric features
    df_scaled = df.copy()
    df_scaled[features] = scaler.transform(df_scaled[features].values)

    # Create the most recent window (last 48 rows)
    if len(df_scaled) < SEQ_LEN:
        raise ValueError(
            f"Not enough data rows ({len(df_scaled)}) — need at least {SEQ_LEN}"
        )

    recent_seq = df_scaled[features].values[-SEQ_LEN:]
    X_input = torch.tensor(recent_seq, dtype=torch.float32).unsqueeze(0).to(DEVICE)

    # Load model and run prediction
    model = CNNLSTMModel(input_dim=len(features))
    model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
    model.to(DEVICE)
    model.eval()

    with torch.no_grad():
        pred = model(X_input).cpu().item()

    print(f"Predicted glucose (30 min ahead) using CNN_LSTM: {pred:.2f} mg/dL")
    return pred
