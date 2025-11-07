"""Deterministic insulin calculation helpers.

This module implements function to compute
insulin recommendations given carbohydrate grams and optional
correction parameters. 

Function contract (calculate_insulin):
- inputs: total_carbs_g (float), carb_ratio (g per 1 unit), current_glucose (mg/dL, optional),
  target_bg or target_range, correction_factor (mg/dL per unit), iob (units), min/max dose, rounding
- output: dict with carb_insulin, correction_insulin, iob, recommended_dose, rounded_dose, safety_flags

Edge cases handled:
- Missing/zero carb_ratio (treated as no carb insulin)
- Missing correction_factor or current_glucose (no correction insulin)
- IOB subtraction and min/max clamps
- Rounding to nearest increment (e.g., 0.5 units)
"""

from typing import Optional, Tuple, Dict


def _round_to(value: float, increment: float) -> float:
    if increment and increment > 0:
        return round(value / increment) * increment
    return value


def calculate_insulin(
    total_carbs_g: float,
    carb_ratio: float,
    current_glucose: Optional[float] = None,
    target_bg: Optional[float] = None,
    target_range: Optional[Tuple[float, float]] = None,
    correction_factor: Optional[float] = None,
    iob: float = 0.0,
    min_dose: float = 0.0,
    max_dose: float = 25.0,
    round_to: float = 0.5,
) -> Dict:
    """Return a deterministic insulin recommendation.

    Parameters
    - total_carbs_g: grams of carbohydrates in the meal
    - carb_ratio: grams carbohydrate covered by 1 unit of insulin (g/unit)
    - current_glucose: current blood glucose in mg/dL (optional)
    - target_bg: preferred target blood glucose (mg/dL). If not provided
      and target_range is given, the range's center is used. Defaults to 100
      mg/dL when neither provided.
    - target_range: (min, max) tuple to indicate safe target window
    - correction_factor: mg/dL reduction achieved by 1 unit insulin
    - iob: insulin on board (units) to subtract from recommendation
    - min_dose/max_dose: clamps for the recommended dose
    - round_to: round recommendation to nearest increment (e.g., 0.5)

    Returns a dictionary with breakdown and recommended/rounded doses.
    """

    # Normalize inputs
    try:
        carbs = float(total_carbs_g or 0.0)
    except Exception:
        carbs = 0.0

    try:
        carb_ratio = float(carb_ratio or 0.0)
    except Exception:
        carb_ratio = 0.0

    try:
        iob = float(iob or 0.0)
    except Exception:
        iob = 0.0

    
    if carb_ratio > 0:
        carb_insulin = carbs / carb_ratio
    else:
        carb_insulin = 0.0

    # Determine target center
    if target_bg is not None:
        target_center = float(target_bg)
    elif target_range and len(target_range) == 2:
        target_center = float((target_range[0] + target_range[1]) / 2.0)
    else:
        target_center = 100.0

    # Compute correction insulin if possible
    correction_insulin = 0.0
    safety_flags = []
    if current_glucose is not None and correction_factor and correction_factor > 0:
        try:
            current = float(current_glucose)
            # If the current glucose is below the lower bound,
            # do not recommend correction insulin to avoid hypoglycemia.
            if target_range and current < float(target_range[0]):
                correction_insulin = 0.0
                safety_flags.append('glucose_below_target_range_no_correction')
            else:
                diff = current - target_center
                # Only positive differences create correction insulin
                if diff > 0:
                    correction_insulin = diff / float(correction_factor)
                else:
                    correction_insulin = 0.0
        except Exception:
            correction_insulin = 0.0

    # Combine components and subtract IOB
    raw_recommendation = carb_insulin + correction_insulin - iob

    # Safety: do not recommend negative doses
    recommended = max(raw_recommendation, 0.0)

    # Enforce min/max
    if recommended < min_dose:
        safety_flags.append('below_min_dose')
        recommended = 0.0

    if recommended > max_dose:
        safety_flags.append('clamped_to_max_dose')
        recommended = float(max_dose)

    rounded = float(_round_to(recommended, float(round_to or 0.0)))

    return {
        'carb_insulin': round(carb_insulin, 4),
        'correction_insulin': round(correction_insulin, 4),
        'iob': round(iob, 4),
        'raw_recommendation': round(raw_recommendation, 4),
        'recommended_dose': round(recommended, 4),
        'rounded_dose': round(rounded, 4),
        'safety_flags': safety_flags,
    }

