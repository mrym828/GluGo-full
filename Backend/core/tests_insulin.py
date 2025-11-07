from django.test import TestCase
from .services.insulin import calculate_insulin


class InsulinCalcTests(TestCase):
    def test_carb_only(self):
        # 60g carbs, carb_ratio 10g per unit => 6.0 units
        r = calculate_insulin(total_carbs_g=60, carb_ratio=10)
        self.assertAlmostEqual(r['carb_insulin'], 6.0)
        self.assertEqual(r['correction_insulin'], 0.0)
        self.assertEqual(r['rounded_dose'], 6.0)

    def test_carb_plus_correction(self):
        # 40g carbs -> 4 units; current glucose 200, target 100, correction 50 => (200-100)/50 = 2 units
        r = calculate_insulin(total_carbs_g=40, carb_ratio=10, current_glucose=200, target_bg=100, correction_factor=50)
        self.assertAlmostEqual(r['carb_insulin'], 4.0)
        self.assertAlmostEqual(r['correction_insulin'], 2.0)
        self.assertAlmostEqual(r['rounded_dose'], 6.0)

    def test_iob_subtraction_and_rounding(self):
        # 30g carbs -> 3 units; correction 1 unit; iob 1.4 => raw 2.6 -> rounded to 2.5 (0.5 increment)
        r = calculate_insulin(
            total_carbs_g=30,
            carb_ratio=10,
            current_glucose=150,
            target_bg=100,
            correction_factor=50,
            iob=1.4,
            round_to=0.5,
        )
        self.assertAlmostEqual(r['carb_insulin'], 3.0)
        self.assertAlmostEqual(r['correction_insulin'], 1.0)
        self.assertAlmostEqual(r['rounded_dose'], 2.5)
