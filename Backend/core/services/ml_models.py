"""
ML Model Architectures for Glucose Prediction

This module contains the neural network architectures used for glucose prediction.
The models here must match the architecture used during training.
"""

import torch
from torch import nn


class CNNLSTMModel(nn.Module):
    """
    Hybrid CNN-LSTM Model for Time Series Glucose Prediction
    
    Architecture:
    1. CNN layers extract local patterns from glucose time series
    2. LSTM layers capture long-term temporal dependencies
    3. Fully connected layer produces final prediction
    
    This architecture is particularly effective for glucose prediction because:
    - CNN captures rapid glucose changes (spikes, drops)
    - LSTM remembers patterns over hours (meal effects, circadian rhythms)
    """
    
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
        """
        Initialize CNN-LSTM model
        
        Args:
            input_dim: Number of input features (e.g., 22 engineered features)
            conv_channels: Number of filters in CNN layers
            conv_kernel_size: Size of convolution window
            conv_layers: Number of CNN layers
            lstm_hidden: Hidden size of LSTM
            lstm_layers: Number of LSTM layers
            dropout: Dropout rate for regularization
        """
        super().__init__()
        
        # Build CNN layers
        convs = []
        in_ch = input_dim
        for _ in range(conv_layers):
            convs.append(
                nn.Conv1d(
                    in_channels=in_ch,
                    out_channels=conv_channels,
                    kernel_size=conv_kernel_size,
                    padding=conv_kernel_size // 2,  # Preserve sequence length
                )
            )
            convs.append(nn.ReLU())
            convs.append(nn.BatchNorm1d(conv_channels))
            convs.append(nn.Dropout(dropout))
            in_ch = conv_channels
        self.conv = nn.Sequential(*convs)

        # Build LSTM layers
        self.lstm = nn.LSTM(
            input_size=conv_channels,
            hidden_size=lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        
        # Output layer
        self.fc = nn.Linear(lstm_hidden, 1)
        
        # Initialize weights
        self._init_weights()

    def _init_weights(self):
        """Initialize weights using Xavier uniform distribution"""
        for name, param in self.named_parameters():
            if "weight" in name and param.dim() > 1:
                nn.init.xavier_uniform_(param)
            elif "bias" in name:
                nn.init.constant_(param, 0.0)

    def forward(self, x):
        """
        Forward pass
        
        Args:
            x: Input tensor of shape (batch, seq_len, input_dim)
        
        Returns:
            Predicted glucose value (batch,)
        """
        # CNN expects (batch, channels, seq_len)
        x_conv_in = x.transpose(1, 2)
        x_conv = self.conv(x_conv_in)
        
        # LSTM expects (batch, seq_len, features)
        x_seq = x_conv.transpose(1, 2)
        out, _ = self.lstm(x_seq)
        
        # Use last timestep for prediction
        out = out[:, -1, :]
        out = self.fc(out).squeeze(-1)
        return out