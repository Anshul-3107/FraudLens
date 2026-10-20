import pandas as pd

from config import TRAIN_CSV, TEST_CSV, PROCESSED, FEATURES_PARQUET
from download_data import ensure_data
from features import FEATURES, build_features

ID_COLS = [
    "trans_num", "trans_date_trans_time", "cc_num",
    "merchant", "category", "split", "is_fraud",
]


def load(path, split):
    df = pd.read_csv(path, index_col=0, parse_dates=["trans_date_trans_time"])
    df["split"] = split
    return df


def main():
    ensure_data()
    PROCESSED.mkdir(parents=True, exist_ok=True)

    # Train and test are combined so test rows can use each card's earlier
    # history from the train period (exactly what happens in production).
    raw = pd.concat(
        [load(TRAIN_CSV, "train"), load(TEST_CSV, "test")], ignore_index=True
    )
    print("Building features for", len(raw), "transactions...")
    df = build_features(raw)

    out = df[ID_COLS + FEATURES]
    out.to_parquet(FEATURES_PARQUET, index=False)
    print("Saved:", FEATURES_PARQUET)

    # ---- sanity checks ----
    print("\nrows per split:\n", out["split"].value_counts().to_string())
    print("\nmissing values in features:", int(out[FEATURES].isna().sum().sum()))

    print("\nfraud rate by is_new_merchant:")
    print(out.groupby("is_new_merchant")["is_fraud"].mean().round(4).to_string())

    print("\nfraud rate by txn_count_1h (capped at 3):")
    print(out.groupby(out["txn_count_1h"].clip(upper=3))["is_fraud"].mean().round(4).to_string())

    print("\namt_zscore, legit vs fraud:")
    print(out.groupby("is_fraud")["amt_zscore"].describe().round(2))

    print("\ndist_home_merchant_km, legit vs fraud:")
    print(out.groupby("is_fraud")["dist_home_merchant_km"].describe().round(1))


if __name__ == "__main__":
    main()