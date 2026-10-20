import json

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import precision_recall_curve

from config import ARTIFACTS, FEATURES_PARQUET, PROCESSED
from train import IF_FEATURES, VAL_START, XGB_ISO_FEATURES

# ASSUMPTION: cost of reviewing one flagged transaction (analyst time + friction).
# A missed fraud costs its full transaction amount.
REVIEW_COST = 5.0
GRID = np.round(np.arange(0.01, 1.0, 0.01), 2)


def load_scored():
    df = pd.read_parquet(FEATURES_PARQUET)
    ts = df["trans_date_trans_time"]
    val = df[(df["split"] == "train") & (ts >= VAL_START)].copy()
    test = df[df["split"] == "test"].copy()

    iso = joblib.load(ARTIFACTS / "isolation_forest.joblib")
    model = joblib.load(ARTIFACTS / "xgb_with_iso.joblib")
    for d in (val, test):
        d["iso_score"] = -iso.score_samples(d[IF_FEATURES])
        d["score"] = model.predict_proba(d[XGB_ISO_FEATURES])[:, 1]
    return val, test


def outcome(d, thr, review_cost):
    flagged = d["score"].to_numpy() >= thr
    fraud = d["is_fraud"].to_numpy() == 1
    amt = d["amt"].to_numpy()

    tp = int((flagged & fraud).sum())
    fp = int((flagged & ~fraud).sum())
    fn = int((~flagged & fraud).sum())
    missed_loss = float(amt[~flagged & fraud].sum())
    cost = missed_loss + review_cost * (tp + fp)
    no_model_cost = float(amt[fraud].sum())          # every fraud goes unnoticed

    return {
        "threshold": round(float(thr), 3),
        "alerts": tp + fp,
        "alerts_per_10k": round(10_000 * (tp + fp) / len(d), 1),
        "tp": tp, "fp": fp, "fn": fn,
        "precision": tp / max(tp + fp, 1),
        "recall": tp / max(tp + fn, 1),
        "total_cost": cost,
        "savings_vs_no_model": 1 - cost / no_model_cost,
    }


def f1_threshold(d):
    p, r, thr = precision_recall_curve(d["is_fraud"], d["score"])
    f1 = 2 * p[:-1] * r[:-1] / np.clip(p[:-1] + r[:-1], 1e-12, None)
    return float(thr[np.argmax(f1)])


def cost_threshold(d, review_cost):
    costs = [outcome(d, t, review_cost)["total_cost"] for t in GRID]
    return float(GRID[int(np.argmin(costs))])


def show(rows):
    print(pd.DataFrame(rows).round(3).to_string(index=False))


def false_positive_analysis(test, thr):
    t = test.copy()
    t["flagged"] = t["score"] >= thr
    legit = t[t["is_fraud"] == 0]
    fraud = t[t["is_fraud"] == 1]

    print("\n===== FALSE ALERTS BY CATEGORY (legit transactions only) =====")
    by_cat = legit.groupby("category")["flagged"].agg(
        legit_txns="size", false_alerts="sum", fp_rate="mean"
    )
    print(by_cat.sort_values("false_alerts", ascending=False).head(6).round(5).to_string())

    print("\n===== FALSE ALERTS: NIGHT vs DAY =====")
    print(legit.groupby("is_night")["flagged"].agg(
        legit_txns="size", false_alerts="sum", fp_rate="mean"
    ).round(5).to_string())

    print("\n===== LEGIT TRANSACTIONS: FLAGGED vs NOT FLAGGED (averages) =====")
    cols = ["amt", "amt_zscore", "is_new_merchant", "txn_count_1h", "is_night"]
    print(legit.groupby("flagged")[cols].mean().round(2).to_string())

    print("\n===== FRAUD: CAUGHT vs MISSED (averages) =====")
    caught, missed = fraud[fraud["flagged"]], fraud[~fraud["flagged"]]
    print(f"missed {len(missed)} of {len(fraud)} frauds")
    print(pd.DataFrame({
        "caught": caught[cols].mean(),
        "missed": missed[cols].mean(),
    }).round(2).to_string())
    print("\nmissed fraud by category (top 5):")
    print(missed.groupby("category").size().sort_values(ascending=False).head(5).to_string())


def main():
    val, test = load_scored()

    thr_default = 0.5
    thr_f1 = f1_threshold(val)
    thr_cost = cost_threshold(val, REVIEW_COST)

    print(f"Thresholds chosen on VALIDATION data: F1-optimal={thr_f1:.3f}, "
          f"cost-optimal={thr_cost:.2f} (review cost ${REVIEW_COST})")

    print("\n===== TEST RESULTS BY THRESHOLD POLICY =====")
    rows = []
    for name, thr in [("default 0.5", thr_default),
                      ("F1-optimal", thr_f1),
                      ("cost-optimal", thr_cost)]:
        rows.append({"policy": name, **outcome(test, thr, REVIEW_COST)})
    show(rows)

    print("\n===== SENSITIVITY: how the review cost changes the best threshold =====")
    rows = []
    for rc in (1, 5, 20, 50):
        thr = cost_threshold(val, rc)
        rows.append({"review_cost": rc, **outcome(test, thr, rc)})
    show(rows)

    false_positive_analysis(test, thr_cost)

    # ---- save for the backend and for the next step ----
    with open(ARTIFACTS / "threshold.json", "w") as f:
        json.dump({"threshold": thr_cost, "review_cost": REVIEW_COST}, f, indent=2)

    PROCESSED.mkdir(parents=True, exist_ok=True)
    keep = ["trans_num", "trans_date_trans_time", "cc_num", "merchant",
            "category", "amt", "is_fraud", "score"]
    test[keep].to_parquet(PROCESSED / "test_predictions.parquet", index=False)
    print("\nSaved threshold.json and test_predictions.parquet")


if __name__ == "__main__":
    main()