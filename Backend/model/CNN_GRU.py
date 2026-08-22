import os
import math
import joblib
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_absolute_error, mean_squared_error
from CPEG import *
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader

# Config
DATA_FILE = "Processed_Data/noSteps_features30min.parquet"
MODEL_OUT = "models/cnn_gru_attn_30min_win48.pt"
SCALER_OUT = "models/standard_scaler.pkl"
SEED = 42
SEQ_LEN = 48  # 48 * 5min = 240min (4 hours history)
BATCH_SIZE = 64
EPOCHS = 50
LR = 1e-3
PATIENCE = 8  # early stopping patience on val loss
VAL_FRAC = 0.10  # fraction of train per patient used for val

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Device:", device)

np.random.seed(SEED)
torch.manual_seed(SEED)

# 1) Load parquet and split patients
df = pd.read_parquet(DATA_FILE)
unique_patients = df["patient_id"].unique()
x = round(len(unique_patients) * 0.2)
np.random.seed(42)
test_patients = np.random.choice(unique_patients, size=x, replace=False)
train_patients = [p for p in unique_patients if p not in test_patients]

train_df = df[df["patient_id"].isin(train_patients)].copy().reset_index(drop=True)
test_df = df[df["patient_id"].isin(test_patients)].copy().reset_index(drop=True)

# prepare feature list
target_col = "target_glucose"
exclude_cols = ["timestamp", "patient_id", target_col]
features = [c for c in df.columns if c not in exclude_cols]
print("Num features:", len(features))
print("Features sample:", features[:10])

# 2) Split a validation set out of train per-patient (time-based)
train_rows = []
val_rows = []
for pid, g in train_df.groupby("patient_id"):
    n = len(g)
    split_idx = int(n * (1 - VAL_FRAC))
    idxs = g.index.values
    train_rows.extend(idxs[:split_idx].tolist())
    val_rows.extend(idxs[split_idx:].tolist())

train_df_sub = train_df.loc[train_rows].reset_index(drop=True)
val_df_sub = train_df.loc[val_rows].reset_index(drop=True)

print(
    "Train rows:",
    len(train_df_sub),
    "Val rows:",
    len(val_df_sub),
    "Test rows:",
    len(test_df),
)

# 3) Fit StandardScaler on train features only; transform train/val/test
scaler = StandardScaler()
scaler.fit(train_df_sub[features].values)  # fit only on training features

train_df_sub_scaled = train_df_sub.copy()
val_df_sub_scaled = val_df_sub.copy()
test_df_scaled = test_df.copy()

train_df_sub_scaled[features] = scaler.transform(train_df_sub[features].values)
val_df_sub_scaled[features] = scaler.transform(val_df_sub[features].values)
test_df_scaled[features] = scaler.transform(test_df[features].values)


# 4) Sequence creation helper (per-patient, no crossing)
def create_sequences_from_df(df_in, features, seq_len):
    X_list, y_list, ts_list, pid_list = [], [], [], []
    for pid, group in df_in.groupby("patient_id"):
        g = group.sort_values("timestamp").reset_index(drop=True)
        arr_X = g[features].values
        arr_y = g[target_col].values
        arr_ts = g["timestamp"].values
        L = len(g)
        for i in range(0, L - seq_len):
            X_list.append(arr_X[i : i + seq_len])
            y_list.append(arr_y[i + seq_len])
            ts_list.append(arr_ts[i + seq_len])  # timestamp of the target
            pid_list.append(pid)
    if len(X_list) == 0:
        return np.empty((0, seq_len, len(features))), np.empty((0,)), [], []
    X = np.stack(X_list, axis=0)
    y = np.array(y_list, dtype=float)
    return X, y, ts_list, pid_list


X_train, y_train, ts_train, pid_train = create_sequences_from_df(
    train_df_sub_scaled, features, SEQ_LEN
)
X_val, y_val, ts_val, pid_val = create_sequences_from_df(
    val_df_sub_scaled, features, SEQ_LEN
)
X_test, y_test, ts_test, pid_test = create_sequences_from_df(
    test_df_scaled, features, SEQ_LEN
)

print("Shapes -> X_train:", X_train.shape, "y_train:", y_train.shape)
print("X_val:", X_val.shape, "X_test:", X_test.shape)


# 5) PyTorch Dataset / DataLoader
class SeqDataset(Dataset):
    def __init__(self, X, y):
        self.X = torch.tensor(X, dtype=torch.float32)
        self.y = torch.tensor(y, dtype=torch.float32)

    def __len__(self):
        return len(self.y)

    def __getitem__(self, idx):
        return self.X[idx], self.y[idx]


train_ds = SeqDataset(X_train, y_train)
val_ds = SeqDataset(X_val, y_val)
test_ds = SeqDataset(X_test, y_test)

train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True)
val_loader = DataLoader(val_ds, batch_size=BATCH_SIZE, shuffle=False)
test_loader = DataLoader(test_ds, batch_size=BATCH_SIZE, shuffle=False)


# 6) CNN + GRU + Attention model definition (GRU: 2 layers, hidden=96)
class AttentionLayer(nn.Module):
    """
    Simple additive attention over recurrent outputs.
    Input: outputs (batch, seq_len, hidden_dim)
    Output: context vector (batch, hidden_dim)
    """

    def __init__(self, hidden_dim):
        super().__init__()
        self.project = nn.Linear(hidden_dim, hidden_dim, bias=True)
        self.score = nn.Linear(hidden_dim, 1, bias=False)

    def forward(self, outputs):
        # outputs: (batch, seq_len, hidden_dim)
        u = torch.tanh(self.project(outputs))  # (batch, seq_len, hidden_dim)
        scores = self.score(u).squeeze(-1)  # (batch, seq_len)
        weights = torch.softmax(scores, dim=1)  # (batch, seq_len)
        context = torch.bmm(weights.unsqueeze(1), outputs).squeeze(
            1
        )  # (batch, hidden_dim)
        return context, weights


class CNNGRUAttnModel(nn.Module):
    def __init__(
        self,
        input_dim,
        conv_channels=64,
        conv_kernel_size=3,
        conv_layers=2,
        gru_hidden=96,
        gru_layers=2,
        dropout=0.3,
    ):
        super().__init__()
        # Temporal conv stack
        convs = []
        in_ch = input_dim
        for i in range(conv_layers):
            out_ch = conv_channels
            convs.append(
                nn.Conv1d(
                    in_channels=in_ch,
                    out_channels=out_ch,
                    kernel_size=conv_kernel_size,
                    padding=conv_kernel_size // 2,
                )
            )
            convs.append(nn.ReLU())
            convs.append(nn.BatchNorm1d(out_ch))
            convs.append(nn.Dropout(dropout))
            in_ch = out_ch
        self.conv = nn.Sequential(*convs)

        # GRU operates on conv features
        self.gru = nn.GRU(
            input_size=conv_channels,
            hidden_size=gru_hidden,
            num_layers=gru_layers,
            batch_first=True,
            dropout=dropout if gru_layers > 1 else 0.0,
        )

        self.attn = AttentionLayer(gru_hidden)
        self.fc = nn.Linear(gru_hidden, 1)
        self._init_weights()

    def _init_weights(self):
        for name, param in self.named_parameters():
            if "weight" in name and param.dim() > 1:
                nn.init.xavier_uniform_(param)
            elif "bias" in name:
                nn.init.constant_(param, 0.0)

    def forward(self, x):
        # x: (batch, seq_len, input_dim)
        x_conv_in = x.transpose(1, 2)  # -> (batch, input_dim, seq_len)
        x_conv = self.conv(x_conv_in)  # -> (batch, conv_channels, seq_len)
        x_seq = x_conv.transpose(1, 2)  # -> (batch, seq_len, conv_channels)
        out, _ = self.gru(x_seq)  # -> (batch, seq_len, hidden)
        context, weights = self.attn(out)  # context: (batch, hidden)
        out = self.fc(context).squeeze(-1)  # -> (batch,)
        return out, weights


# instantiate model
model = CNNGRUAttnModel(
    input_dim=len(features),
    conv_channels=64,
    conv_kernel_size=3,
    conv_layers=2,
    gru_hidden=96,
    gru_layers=2,
    dropout=0.3,
).to(device)

criterion = nn.MSELoss()
optimizer = torch.optim.Adam(model.parameters(), lr=LR, weight_decay=1e-5)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
    optimizer, mode="min", factor=0.5, patience=4
)

print(model)

# 7) Training loop with early stopping + scheduler
best_val_loss = float("inf")
best_epoch = -1
patience_ctr = 0

for epoch in range(1, EPOCHS + 1):
    model.train()
    train_losses = []
    for Xb, yb in train_loader:
        Xb = Xb.to(device)
        yb = yb.to(device)
        optimizer.zero_grad()
        preds, _ = model(Xb)
        loss = criterion(preds, yb)
        loss.backward()
        optimizer.step()
        train_losses.append(loss.item())

    # validation
    model.eval()
    val_losses = []
    with torch.no_grad():
        for Xb, yb in val_loader:
            Xb = Xb.to(device)
            yb = yb.to(device)
            preds, _ = model(Xb)
            loss = criterion(preds, yb)
            val_losses.append(loss.item())

    avg_train = np.mean(train_losses) if train_losses else float("nan")
    avg_val = np.mean(val_losses) if val_losses else float("nan")
    print(
        f"Epoch {epoch}/{EPOCHS} — train_loss: {avg_train:.5f}, val_loss: {avg_val:.5f}"
    )

    # step scheduler on val (and simple logging if LR reduced)
    old_lr = optimizer.param_groups[0]["lr"]
    scheduler.step(avg_val)
    new_lr = optimizer.param_groups[0]["lr"]
    if new_lr < old_lr:
        print(f"LR reduced from {old_lr:.6f} to {new_lr:.6f}")

    # early stopping & save best
    if avg_val < best_val_loss - 1e-5:
        best_val_loss = avg_val
        best_epoch = epoch
        patience_ctr = 0
        torch.save(model.state_dict(), MODEL_OUT + ".best")
    else:
        patience_ctr += 1
        if patience_ctr >= PATIENCE:
            print(
                f"Early stopping at epoch {epoch}. Best epoch: {best_epoch} (val_loss={best_val_loss:.5f})"
            )
            break

# reload best model
if os.path.exists(MODEL_OUT + ".best"):
    model.load_state_dict(torch.load(MODEL_OUT + ".best", map_location=device))

# 8) Evaluate on test set (compute MAE & RMSE)
model.eval()
preds_all = []
true_all = []
attn_weights_list = []  # optional: store attention weights for inspection
with torch.no_grad():
    for Xb, yb in test_loader:
        Xb = Xb.to(device)
        out, weights = model(Xb)
        out = out.cpu().numpy()
        preds_all.extend(out.tolist())
        true_all.extend(yb.numpy().tolist())
        attn_weights_list.append(weights.cpu().numpy())

mae = mean_absolute_error(true_all, preds_all)
rmse = math.sqrt(mean_squared_error(true_all, preds_all))
y_true = np.array(true_all)
y_preds = np.array(preds_all)
mape = np.mean(np.abs((y_true - y_preds) / y_true)) * 100
print(f"\nTest MAE: {mae:.2f}, Test RMSE: {rmse:.2f}, MAPE: {mape:.2f}%")

# 9) Build comparison dataframe and plot one test patient
comparison_df = pd.DataFrame(
    {
        "timestamp": ts_test,
        "patient_id": pid_test,
        "target_glucose": true_all,
        "predicted_glucose": preds_all,
    }
)
comparison_df["timestamp"] = pd.to_datetime(comparison_df["timestamp"])
comparison_df = comparison_df.sort_values(["patient_id", "timestamp"]).reset_index(
    drop=True
)

pid_plot = test_patients[0]
patient_plot = comparison_df[comparison_df["patient_id"] == pid_plot]

plt.figure(figsize=(12, 5))
plt.plot(
    patient_plot["timestamp"],
    patient_plot["target_glucose"],
    label="Actual (target)",
    linewidth=2,
)
plt.plot(
    patient_plot["timestamp"],
    patient_plot["predicted_glucose"],
    label="Predicted",
    linewidth=2,
    alpha=0.8,
)
plt.title(f"CNN-GRU-Attn (window={SEQ_LEN}) — Patient {pid_plot} — 30 min ahead")
plt.xlabel("Timestamp")
plt.ylabel("Glucose (mg/dL)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()

# Clarke error grid
plot, zone = clarke_error_grid(true_all, preds_all, "GluPred")
plot.show()
total = sum(zone)
percentages = [(z / total) * 100 for z in zone]
labels = ["A", "B", "C", "D", "E"]
for L, p in zip(labels, percentages):
    print(f"Zone {L}: {p:.2f}%")
acc = percentages[0] + percentages[1]
print(f"\n{acc:.2f}% of predictions are clinically acceptable")

# 10) Save final model and scaler
os.makedirs("models", exist_ok=True)
torch.save(model.state_dict(), MODEL_OUT)
joblib.dump(scaler, SCALER_OUT)
print("\nSaved model ->", MODEL_OUT)
print("Saved scaler ->", SCALER_OUT)
