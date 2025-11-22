from CNN_LSTM_Predict import predict_next_glucose
from lgb_predicts import predict_next_glucoselgb

dataset = [37, 38, 64, 65, 66]
for i in dataset:
    csv_file = f"{i}.csv"
    print(f"\nFor patient {i}:")
    predict_next_glucose(csv_file)  # cnn_lstm prediction
    predict_next_glucoselgb(csv_file)  # lgb prediction
