"""
Regression tests for the ML prediction feature pipeline (Phases 0-4).

These guard against the exact bug class found and fixed this session:
_predict_lightgbm and _predict_cnn_lstm silently building a feature vector
that didn't match what the models were actually trained on, so both ended
up either failing to load or returning a fixed, data-blind number instead
of a real prediction. The core assertion running through this file is
simple but was the one thing that would have caught it immediately:
different input data must produce different output.

Skips (rather than fails) when the model files or ML dependencies aren't
available in the current environment, since those are real, chunky binary
files under Backend/model/ that not every environment will have.
"""
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from .models import FoodEntry, GlucoseRecord, InsulinDose
from .services.prediction import prediction_service, TORCH_AVAILABLE, LIGHTGBM_AVAILABLE

User = None


def _get_user_model():
    global User
    if User is None:
        from django.contrib.auth import get_user_model
        User = get_user_model()
    return User


def _seed_flat_glucose(user, level, count=25, step_minutes=15):
    """Replace this user's glucose history with a flat series at `level`."""
    GlucoseRecord.objects.filter(user=user, source='verification_temp').delete()
    now = timezone.now()
    for i in range(count - 1, -1, -1):
        GlucoseRecord.objects.create(
            user=user,
            timestamp=now - timedelta(minutes=i * step_minutes),
            glucose_level=level,
            source='verification_temp',
        )


class FeaturePipelineTests(TestCase):
    """Phase 0: the shared feature-engineering pipeline."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        User = _get_user_model()
        cls.user = User.objects.create_user(
            username='prediction_test_user',
            email='prediction_test@glugo.local',
            password='not-used-in-tests',
        )

    def setUp(self):
        if not prediction_service.scaler or not prediction_service.feature_order:
            self.skipTest("scaler/feature_order not loaded — model files unavailable in this environment")
        _seed_flat_glucose(self.user, 130.0)

    def test_build_feature_matrix_shape_and_columns(self):
        df = prediction_service._build_feature_matrix(self.user)
        # 48 requested + 12-slot buffer = 60 rows before NaN warm-up rows are dropped
        self.assertEqual(len(df), 60)
        for col in prediction_service.feature_order:
            self.assertIn(col, df.columns)

    def test_finalize_feature_matrix_shape(self):
        df = prediction_service._build_feature_matrix(self.user)
        matrix = prediction_service._finalize_feature_matrix(df)
        self.assertEqual(matrix.shape, (48, 22))

    def test_scaled_feature_matrix_shape(self):
        scaled = prediction_service.get_scaled_feature_matrix(self.user)
        self.assertEqual(scaled.shape, (48, 22))

    def test_carbs_backfilled_from_food_entry(self):
        """Phase 1: a logged meal's carbs show up as a single spike, not smeared."""
        entry = FoodEntry.objects.create(user=self.user, total_carbs=45.0)
        FoodEntry.objects.filter(id=entry.id).update(
            timestamp=timezone.now() - timedelta(minutes=90)
        )

        raw = prediction_service.prepare_user_data(self.user, lookback_minutes=300)
        nonzero = [d for d in raw if d['carbs']]

        self.assertEqual(len(nonzero), 1, "carbs should attribute to exactly one slot")
        self.assertAlmostEqual(nonzero[0]['carbs'], 45.0)
        self.assertAlmostEqual(sum(d['carbs'] for d in raw), 45.0)

    def test_insulin_backfilled_from_confirmed_dose(self):
        """Phase 2: a confirmed dose's units show up as a single spike, using
        the confirmed value — not the (deliberately different) recommendation."""
        InsulinDose.objects.create(
            user=self.user,
            timestamp=timezone.now() - timedelta(minutes=90),
            units=4.5,
            recommended_units=5.0,
            source='meal',
        )

        raw = prediction_service.prepare_user_data(self.user, lookback_minutes=300)
        nonzero = [d for d in raw if d['insulin']]

        self.assertEqual(len(nonzero), 1, "insulin should attribute to exactly one slot")
        self.assertAlmostEqual(nonzero[0]['insulin'], 4.5)

    def test_iob_decays_after_dose(self):
        InsulinDose.objects.create(
            user=self.user,
            timestamp=timezone.now() - timedelta(minutes=90),
            units=4.5,
            source='meal',
        )
        df = prediction_service._build_feature_matrix(self.user)
        iob_values = df[df['IOB'] > 0]['IOB'].tolist()

        self.assertGreater(len(iob_values), 1, "IOB should carry forward across multiple rows, not just the dose row")
        self.assertTrue(
            all(earlier >= later for earlier, later in zip(iob_values, iob_values[1:])),
            "IOB should monotonically decay after the dose",
        )


class ModelPredictionRegressionTests(TestCase):
    """
    Phases 3-4: the actual model predictions. The core regression check —
    feed genuinely different glucose data, expect genuinely different
    output. This is exactly the check that caught _predict_lightgbm
    silently returning a constant, data-blind 64.84914876088102 regardless
    of input, and would catch it again if the feature pipeline ever
    regresses back to a broken/mismatched vector.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        User = _get_user_model()
        cls.user = User.objects.create_user(
            username='prediction_test_user2',
            email='prediction_test2@glugo.local',
            password='not-used-in-tests',
        )

    def test_lightgbm_responds_to_input_data(self):
        if not (LIGHTGBM_AVAILABLE and prediction_service.lgb_model is not None):
            self.skipTest("LightGBM model not available in this environment")

        _seed_flat_glucose(self.user, 70.0)
        pred_low = prediction_service._predict_lightgbm(self.user)

        _seed_flat_glucose(self.user, 250.0)
        pred_high = prediction_service._predict_lightgbm(self.user)

        self.assertNotAlmostEqual(
            pred_low, pred_high, places=1,
            msg="LightGBM returned the same prediction for glucose=70 and glucose=250 — "
                "it's likely reading an all-zero/mismatched feature vector again.",
        )
        # Sanity: physiologically plausible range, not a constant sentinel.
        self.assertGreater(pred_low, 30)
        self.assertLess(pred_high, 450)

    def test_cnn_lstm_loads_and_responds_to_input_data(self):
        if not (TORCH_AVAILABLE and prediction_service.cnn_lstm_model is not None):
            self.skipTest("CNN-LSTM model not available/loaded in this environment")

        _seed_flat_glucose(self.user, 70.0)
        pred_low = prediction_service._predict_cnn_lstm(self.user)

        _seed_flat_glucose(self.user, 250.0)
        pred_high = prediction_service._predict_cnn_lstm(self.user)

        self.assertNotAlmostEqual(
            pred_low, pred_high, places=1,
            msg="CNN-LSTM returned the same prediction for glucose=70 and glucose=250.",
        )
        self.assertGreater(pred_low, 30)
        self.assertLess(pred_high, 450)

    def test_ensemble_includes_all_available_models(self):
        """
        Guards against a specific past failure mode: a model that's loaded
        and callable but whose prediction gets silently swallowed by an
        internal try/except and never surfaces in predictions_by_model.
        """
        if not prediction_service.loaded:
            self.skipTest("no prediction models loaded in this environment")

        _seed_flat_glucose(self.user, 140.0)
        result = prediction_service.predict_for_user(self.user, model_type='ensemble')

        self.assertTrue(result['success'], result.get('error'))
        available = set(result['metadata']['available_models'])

        self.assertIn('simple', available)
        if LIGHTGBM_AVAILABLE and prediction_service.lgb_model is not None:
            self.assertIn('lgb', available)
        if TORCH_AVAILABLE and prediction_service.cnn_lstm_model is not None:
            self.assertIn('cnn_lstm', available)
