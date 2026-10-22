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
    return 6371.0 * 2 * np.arcsin(np.sqrt(np.clip(a, 0.0, 1.0)))


def _count_in_window(df, window_seconds):
    """For each row, count earlier transactions on the same card within the window.
    df must be sorted by (cc_num, unix_time) with a default RangeIndex."""
    out = np.zeros(len(df), dtype=np.int32)
    t_all = df["unix_time"].to_numpy()
    for _, idx in df.groupby("cc_num").indices.items():
        t = t_all[idx]
        start = np.searchsorted(t, t - window_seconds, side="left")
        end = np.searchsorted(t, t, side="left")
        out[idx] = end - start
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
    ts_naive = ts.dt.tz_localize(None) if getattr(ts.dt, "tz", None) is not None else ts
    df["age"] = (ts_naive - pd.to_datetime(df["dob"])).dt.days / 365.25
    df["gender_male"] = (df["gender"] == "M").astype(int)
    df["log_city_pop"] = np.log1p(df["city_pop"])
    dist = haversine_km(
        df["lat"], df["long"], df["merch_lat"], df["merch_long"]
    )
    df["dist_home_merchant_km"] = dist.fillna(76.0)

    # ---- per-card behaviour, using ONLY earlier transactions (strictly causal) ----
    amt_all = df["amt"].to_numpy(dtype=float)
    t_all = df["unix_time"].to_numpy(dtype=np.int64)
    merch_all = df["merchant"].to_numpy()
    cat_all = df["category"].to_numpy()

    n_arr = np.zeros(len(df), dtype=np.int32)
    zscore_arr = np.zeros(len(df), dtype=float)
    ratio_arr = np.ones(len(df), dtype=float)
    secs_arr = np.full(len(df), 30 * 86400.0, dtype=float)
    is_new_m = np.zeros(len(df), dtype=np.int32)
    is_new_c = np.zeros(len(df), dtype=np.int32)

    for _, idx in df.groupby("cc_num").indices.items():
        t = t_all[idx]
        a = amt_all[idx]
        m = merch_all[idx]
        c = cat_all[idx]

        end = np.searchsorted(t, t, side="left")
        n_arr[idx] = end

        last_idx = end - 1
        secs_arr[idx] = np.where(last_idx >= 0, t - t[np.maximum(last_idx, 0)], 30 * 86400.0)

        cum_a = np.concatenate([[0.0], np.cumsum(a)])
        cum_a2 = np.concatenate([[0.0], np.cumsum(a ** 2)])
        s1 = cum_a[end]
        s2 = cum_a2[end]

        with np.errstate(divide="ignore", invalid="ignore"):
            mean = np.where(end >= 1, s1 / end, 0.0)
            var = np.where(end >= 2, (s2 - (s1 ** 2) / end) / (end - 1), 0.0)
            var = np.maximum(var, 0.0)
            std = np.maximum(np.sqrt(var), 1.0)
            enough = end >= 5
            zscore_arr[idx] = np.where(enough, (a - mean) / std, 0.0)
            ratio_arr[idx] = np.where(enough, a / np.maximum(mean, 1.0), 1.0)

        for i_pos in range(len(t)):
            prior_end = end[i_pos]
            is_new_m[idx[i_pos]] = int(m[i_pos] not in m[:prior_end])
            is_new_c[idx[i_pos]] = int(c[i_pos] not in c[:prior_end])

    df["card_prior_count"] = n_arr
    df["amt_zscore"] = zscore_arr
    df["amt_ratio_to_mean"] = ratio_arr
    df["secs_since_last"] = secs_arr
    df["txn_count_1h"] = _count_in_window(df, 3600)
    df["txn_count_24h"] = _count_in_window(df, 86400)
    df["is_new_merchant"] = is_new_m
    df["is_new_category"] = is_new_c

    return df