import numpy as np
import xgboost as xgb

from features import CATEGORIES

# Features are grouped into human-level factors. Demographic features
# (age, gender_male, log_city_pop) and card_prior_count are intentionally
# NOT in any group, so they are never shown to a user as a "reason".
GROUPS = {
    "amount": ["amt", "log_amt", "amt_zscore", "amt_ratio_to_mean"],
    "time": ["is_night", "hour", "dayofweek"],
    "category": ["category_code"],
    "velocity": ["txn_count_1h", "txn_count_24h", "secs_since_last"],
    "novelty": ["is_new_merchant", "is_new_category"],
    "rarity": ["iso_score"],
    "location": ["dist_home_merchant_km"],
}

# Categories whose training fraud rate is above the overall rate (about 0.58%).
HIGH_RISK_CATEGORIES = {"shopping_net", "misc_net", "grocery_pos", "shopping_pos"}


def _amount(r):
    amt = r["amt"]
    # when a card has too little history, z-score is 0 and ratio is 1 (neutral values)
    has_history = r["amt_zscore"] != 0.0 or r["amt_ratio_to_mean"] != 1.0
    if has_history:
        ratio = r["amt_ratio_to_mean"]
        if ratio >= 2:
            return f"Amount ${amt:,.2f} is {ratio:.1f}x this card's average spend"
        if ratio <= 0.5:
            return f"Amount ${amt:,.2f} is unusually small for this card ({ratio:.1f}x its average)"
    return f"Amount ${amt:,.2f} falls in a range associated with fraud"


def _time(r):
    hour = int(r["hour"])
    if r["is_night"]:
        return f"Late-night transaction ({hour:02d}:00)"
    return f"Transaction time ({hour:02d}:00) is associated with higher fraud risk"


def _category(r):
    name = CATEGORIES[int(r["category_code"])]
    label = name.replace("_", " ")
    if name in HIGH_RISK_CATEGORIES:
        return f"Higher-risk spending category: {label}"
    return f"Category '{label}' looks unusual alongside the other details of this transaction"


def _velocity(r):
    n1h, n24h = int(r["txn_count_1h"]), int(r["txn_count_24h"])
    if n1h >= 1:
        return f"{n1h} other transaction(s) on this card within the last hour"
    if n24h >= 1:
        return f"{n24h} other transaction(s) on this card within the last 24 hours"
    return "Unusual timing since the previous transaction on this card"


def _novelty(r):
    if r["is_new_merchant"]:
        return "First time this card is used at this merchant"
    if r["is_new_category"]:
        return "First purchase in this category for this card"
    return "Merchant and category pattern is unusual for this card"


def _rarity(r):
    return "The overall combination of details is rare compared with normal activity"


def _location(r):
    return f"Merchant is {r['dist_home_merchant_km']:.0f} km from the cardholder's home"


TEXT = {
    "amount": _amount,
    "time": _time,
    "category": _category,
    "velocity": _velocity,
    "novelty": _novelty,
    "rarity": _rarity,
    "location": _location,
}


def shap_contribs(model, X):
    """TreeSHAP values in log-odds. Shape (n, n_features + 1); last column is the bias."""
    booster = model.get_booster()
    dmatrix = xgb.DMatrix(X[booster.feature_names])
    return booster.predict(
        dmatrix, pred_contribs=True, iteration_range=(0, model.best_iteration + 1)
    )


def explain(model, X, top_k=3, min_contrib=0.1):
    """Return, for each row of X, a list of the top factors pushing toward 'fraud'."""
    feature_names = model.get_booster().feature_names
    X = X[feature_names]
    contribs = shap_contribs(model, X)

    idx = {name: i for i, name in enumerate(feature_names)}
    # Support both ensemble (15 features with iso_score) and standalone candidate (14 features).
    # Filters factor groups dynamically based on features present in the model's booster.
    active_groups = {
        g: [f for f in cols if f in idx]
        for g, cols in GROUPS.items()
        if any(f in idx for f in cols)
    }
    group_names = list(active_groups)
    scores = np.column_stack([
        contribs[:, [idx[f] for f in active_groups[g]]].sum(axis=1) for g in group_names
    ])

    rows = X.to_dict("records")
    out = []
    for i, row in enumerate(rows):
        order = np.argsort(-scores[i])[:top_k]
        out.append([
            {
                "factor": group_names[j],
                "impact": round(float(scores[i, j]), 3),
                "text": TEXT[group_names[j]](row),
            }
            for j in order
            if scores[i, j] >= min_contrib
        ])
    return out