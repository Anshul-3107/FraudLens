import numpy as np
import pandas as pd

# Fixed list so the same mapping can be reused later by the Django backend.
CATEGORIES = [
    "entertainment", "food_dining", "gas_transport", "grocery_net", "grocery_pos",
    "health_fitness", "home", "kids_pets", "misc_net", "misc_pos",
    "personal_care", "shopping_net", "shopping_pos", "travel",
]

# Model inputs.
# Deliberately EXCLUDED (still computed in build_features, but not used by the model):
#   age, gender_male, log_city_pop  -> demographic; a fraud decision should not use them
#   card_prior_count                -> proxy for time on file / cardholder identity
# Ablation (test PR-AUC): with them 0.903, without them 0.859.
FEATURES = [
    # transaction itself
    "amt", "log_amt", "hour", "dayofweek", "is_night", "category_code",
    # location
    "dist_home_merchant_km",
    # per-card behaviour (past transactions only)
    "amt_zscore", "amt_ratio_to_mean",
    "secs_since_last", "txn_count_1h", "txn_count_24h",
    "is_new_merchant", "is_new_category",
]


def haversine_km(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = (np.radians(x) for x in (lat1, lon1, lat2, lon2))
    a = (np.sin((lat2 - lat1) / 2) ** 2
         + np.cos(lat1) * np.cos(lat2) * np.sin((lon2 - lon1) / 2) ** 2)
    return 6371.0 * 2 * np.arcsin(np.sqrt(a))


def _count_in_window(df, window_seconds):
    """For each row, count earlier transactions on the same card within the window.
    df must be sorted by (cc_num, unix_time) with a default RangeIndex."""
    out = np.zeros(len(df), dtype=np.int32)
    t_all = df["unix_time"].to_numpy()
    for _, idx in df.groupby("cc_num").indices.items():
        t = t_all[idx]
        start = np.searchsorted(t, t - window_seconds, side="left")
        out[idx] = np.arange(len(t)) - start
    return out


def build_features(raw: pd.DataFrame) -> pd.DataFrame:
    df = raw.sort_values(["cc_num", "unix_time"], kind="stable").reset_index(drop=True)
    ts = df["trans_date_trans_time"]

    # ---- transaction-level features ----
    df["hour"] = ts.dt.hour
    df["dayofweek"] = ts.dt.dayofweek
    df["is_night"] = ((df["hour"] >= 22) | (df["hour"] <= 3)).astype(int)
    df["log_amt"] = np.log1p(df["amt"])
    df["category_code"] = df["category"].map({c: i for i, c in enumerate(CATEGORIES)})

    # ---- cardholder / location features ----
    df["age"] = (ts - pd.to_datetime(df["dob"])).dt.days / 365.25
    df["gender_male"] = (df["gender"] == "M").astype(int)
    df["log_city_pop"] = np.log1p(df["city_pop"])
    df["dist_home_merchant_km"] = haversine_km(
        df["lat"], df["long"], df["merch_lat"], df["merch_long"]
    )

    # ---- per-card behaviour, using ONLY earlier transactions ----
    g = df.groupby("cc_num")
    amt = df["amt"]
    n = g.cumcount()                                   # number of prior transactions
    n_safe = n.replace(0, np.nan)

    s1 = g["amt"].cumsum() - amt                       # sum of prior amounts
    s2 = (amt ** 2).groupby(df["cc_num"]).cumsum() - amt ** 2
    mean = s1 / n_safe
    var = ((s2 - s1 ** 2 / n_safe) / (n - 1).replace(0, np.nan)).clip(lower=0)
    std = np.sqrt(var).clip(lower=1.0)

    enough_history = n >= 5                            # otherwise: neutral values
    df["card_prior_count"] = n
    df["amt_zscore"] = np.where(enough_history, (amt - mean) / std, 0.0)
    df["amt_ratio_to_mean"] = np.where(enough_history, amt / mean.clip(lower=1.0), 1.0)

    df["secs_since_last"] = g["unix_time"].diff().fillna(30 * 86400)
    df["txn_count_1h"] = _count_in_window(df, 3600)
    df["txn_count_24h"] = _count_in_window(df, 86400)

    df["is_new_merchant"] = (df.groupby(["cc_num", "merchant"]).cumcount() == 0).astype(int)
    df["is_new_category"] = (df.groupby(["cc_num", "category"]).cumcount() == 0).astype(int)

    return df