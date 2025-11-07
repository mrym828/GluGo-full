"""Utility helpers for the core app.

This module contains carb-estimation fallback used when the
AI/remote service does not provide per-component carbohydrate estimates.
"""

# Simple lookup table mapping common ingredient keywords to an approximate
# carbs-per-serving value (grams). 
COMMON_CARB_LOOKUP = {
    'burger bun': 30.0,
    'bun': 30.0,
    'beef patty': 0.0,
    'lettuce': 1.0,
    'tomato': 1.0,
    'onion': 2.0,
    'cheese': 1.0,
    'potato wedges': 40.0,
    'fries': 40.0,
    'potato': 20.0,
    'rice': 45.0,
    'pasta': 40.0,
}


def estimate_components_carbs(components):
    """
    Normalize a components list and estimate carbs where missing.

    Input:
      components: list of either strings (ingredient names) or dicts with
                  keys like 'name' and optionally 'carbs_g'.

    Output:
      (normalized_list, total_carbs)
      - normalized_list: list of dicts {'name':str, 'carbs_g':float|None}
      - total_carbs: float rounded to 1 decimal place or None if no numeric
        estimates were available

    The function first prefers numeric `carbs_g` provided by the client/AI.
    If an item has no numeric carbs we attempt a substring lookup using the
    small `COMMON_CARB_LOOKUP` table above. This provides a deterministic
    fallback when the AI omits numbers.
    """
    normalized = []
    total = 0.0
    have_number = False

    for c in components or []:
        # Extract a human-readable name and any provided carbs value
        if isinstance(c, dict):
            name = c.get('name') or c.get('ingredient') or str(c)
            carbs = c.get('carbs_g') if 'carbs_g' in c else c.get('carbs')
        else:
            name = str(c)
            carbs = None

        carbs_val = None
        # Prefer explicit numeric carbs if the client provided them
        if carbs is not None:
            try:
                carbs_val = round(float(carbs), 1)
            except Exception:
                carbs_val = None

        # Otherwise try the simple lookup table using substring matching
        if carbs_val is None:
            key = name.lower()
            for k in COMMON_CARB_LOOKUP:
                if k in key:
                    carbs_val = COMMON_CARB_LOOKUP[k]
                    break

        if carbs_val is not None:
            have_number = True
            total += float(carbs_val)

        normalized.append({'name': name, 'carbs_g': carbs_val})

    total_rounded = round(total, 1) if have_number else None
    return normalized, total_rounded

