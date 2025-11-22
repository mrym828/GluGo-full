import torch
import torch.nn as nn

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