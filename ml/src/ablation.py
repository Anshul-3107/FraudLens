import pandas as pd
from sklearn.ensemble import IsolationForest

from config import FEATURES_PARQUET
from features import FEATURES
from train import SEED, VAL_START, evaluate, train_xgb
from tune_threshold import REVIEW_COST, cost_threshold, outcome

DEMOGRAPHICS = ["age", "gender_male", "log_city_pop"]

VARIANTS = {
    "all features (current)": [],
    "no demographics": DEMOGRAPHICS,
    "no demographics, no card_prior_count": DEMOGRAPHICS + ["card_prior_count"],
}


def run_variant(name, drop, fit, val, test):
    feats = [f for f in FEATURES if f not in drop]
    if_feats = [f for f in feats if f != "category_code"]

    print(f"\n[{name}] Isolation Forest on {len(if_feats)} features...")
    iso = IsolationForest(n_estimators=200, max_samples=256,
                          random_state=SEED, n_jobs=-1)
    iso.fit(fit[if_feats])
    for d in (fit, val, test):
        d["iso_score"] = -iso.score_samples(d[if_feats])

    cols = feats + ["iso_score"]
    print(f"[{name}] XGBoost on {len(cols)} features...")
    model = train_xgb(fit, val, cols)
    val["score"] = model.predict_proba(val[cols])[:, 1]
    test["score"] = model.predict_proba(test[cols])[:, 1]

    row = evaluate(name, val["is_fraud"], val["score"], test["is_fraud"], test["score"])
    thr = cost_threshold(val, REVIEW_COST)
    res = outcome(test, thr, REVIEW_COST)
    row.update({
        "cost_thr": thr,
        "alerts_per_10k": res["alerts_per_10k"],
        "precision": res["precision"],
        "recall": res["recall"],
        "test_cost": res["total_cost"],
    })
    return row


def main():
    df = pd.read_parquet(FEATURES_PARQUET)
    ts = df["trans_date_trans_time"]
    is_train = df["split"] == "train"

    fit = df[is_train & (ts < VAL_START)].copy()
    val = df[is_train & (ts >= VAL_START)].copy()
    test = df[df["split"] == "test"].copy()

    rows = [run_variant(n, drop, fit, val, test) for n, drop in VARIANTS.items()]

    print("\n===== ABLATION RESULTS =====")
    table = pd.DataFrame(rows)
    keep = ["model", "val_pr_auc", "test_pr_auc", "test_recall@90%prec",
            "cost_thr", "alerts_per_10k", "precision", "recall", "test_cost"]
    print(table[keep].round(4).to_string(index=False))


if __name__ == "__main__":
    main()