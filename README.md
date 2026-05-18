GluGo — Manage Glucose On-The-Go
<p align="center"> <img src="assets/banner.png" alt="GluGo Banner" width="100%"> </p> <p align="center"> <img src="https://img.shields.io/badge/Flutter-Mobile_App-02569B?logo=flutter" /> <img src="https://img.shields.io/badge/Django-Backend-092E20?logo=django" /> <img src="https://img.shields.io/badge/Python-ML_&_API-3776AB?logo=python" /> <img src="https://img.shields.io/badge/OpenAI-Vision_API-412991?logo=openai" /> <img src="https://img.shields.io/badge/Status-Completed-success" /> <img src="https://img.shields.io/badge/License-Academic_Project-blue" /> </p> <p align="center"> AI-powered diabetes management application combining glucose prediction, meal analysis, insulin recommendation, and real-time health monitoring. </p>

Demo Video link: https://youtube.com/shorts/DbtHsK2bgwQ?si=hkENzXd00yFhDB-T 

The system combines:

Mobile application development
Backend REST APIs
Machine learning glucose prediction models
Continuous glucose monitor (CGM) integration
AI-powered food analysis

Features
AI Food Analysis
Upload or capture meal images
AI-based nutritional estimation using OpenAI Vision API
Carbohydrates, fats, and proteins extraction
Automatic insulin recommendation calculation
Glucose Monitoring
Manual glucose logging
Real-time CGM integration with LibreView
Glucose trends visualization
Historical glucose tracking
Insulin Recommendation System
Personalized insulin dose calculation
Uses:
Carb ratio
Correction factor
Current glucose level
Target glucose range
Machine Learning Prediction
Predict future glucose levels
30-minute and 60-minute forecasting
Multiple ML architectures implemented:
LightGBM
XGBoost
CatBoost
LSTM
CNN + LSTM Hybrid
Insights & Analytics
Time-in-range statistics
Glucose trend analysis
Personalized insights dashboard
High/low glucose alerts

System Architecture
Frontend

Built using:

Flutter
Dart
Material Design

Frontend includes:

Authentication screens
Dashboard
Food scanning interface
Glucose charts
Insights dashboard
Device integration screens
Backend

Built using:

Python
Django 5.x
Django REST Framework (DRF)

Backend features:

JWT Authentication
RESTful APIs
OpenAI integration
LibreView integration
Glucose prediction APIs
Insulin calculation services
Machine Learning

Implemented models:

LightGBM
XGBoost
CatBoost
LSTM
CNN-LSTM Hybrid

Evaluation metrics:

MAE
RMSE
MAPE
Clarke Error Grid
Parkes Error Grid

Best clinical safety achieved:

98%+ clinically acceptable predictions

**License**
This project was developed for academic purposes as a senior graduation project at the University of Sharjah.
