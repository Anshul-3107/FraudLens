import joblib
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import (
    average_precision_score,
    precision_recall_curve,
    roc_auc_score,
)
from xgboost import XGBClassifier

from config import ARTIFACTS, FEATURES_PARQUET
from features import FEATURES

SEED = 42
VAL_START = pd.Timestamp("2020-03-01")          # time-based validation window
IF_FEATURES = [f for f in FEATURES if f != "category_code"]
XGB_FEATURES = FEATURES
XGB_ISO_FEATURES = FEATURES + ["iso_score"]


def recall_at_precision(y, scores, target):
    precision, recall, _ = precision_recall_curve(y, scores)
    ok = precision >= target
    return float(recall[ok].max()) if ok.any() else 0.0


def evaluate(name, y_val, s_val, y_test, s_test):
    return {
        "model": name,
        "val_pr_auc": average_precision_score(y_val, s_val),
        "test_pr_auc": average_precision_score(y_test, s_test),
        "test_roc_auc": roc_auc_score(y_test, s_test),
        "test_recall@50%prec": recall_at_precision(y_test, s_test, 0.50),
        "test_recall@90%prec": recall_at_precision(y_test, s_test, 0.90),
    }


def train_xgb(fit, val, cols):
    pos = fit["is_fraud"].sum()
    neg = len(fit) - pos
    model = XGBClassifier(
        n_estimators=1000,
        learning_rate=0.05,
        max_depth=6,
        subsample=0.8,
        colsample_bytree=0.8,
        scale_pos_weight=neg / pos,             # handles the class imbalance
        eval_metric="aucpr",
        early_stopping_rounds=50,
        tree_method="hist",
        n_jobs=-1,
        random_state=SEED,
    )
    model.fit(
        fit[cols], fit["is_fraud"],
        eval_set=[(val[cols], val["is_fraud"])],
        verbose=False,
    )
    print(f"  best iteration: {model.best_iteration}")
    return model


def main():
    ARTIFACTS.mkdir(parents=True, exist_ok=True)

    df = pd.read_parquet(FEATURES_PARQUET)
    ts = df["trans_date_trans_time"]
    is_train = df["split"] == "train"

    fit = df[is_train & (ts < VAL_START)].copy()
    val = df[is_train & (ts >= VAL_START)].copy()
    test = df[df["split"] == "test"].copy()

    for name, d in [("fit", fit), ("val", val), ("test", test)]:
        print(f"{name:5s} rows={len(d):>8,}  fraud={int(d.is_fraud.sum()):>5,}  "
              f"rate={d.is_fraud.mean():.3%}")
    print(f"(a random model would score a PR-AUC of about {test.is_fraud.mean():.4f} on test)\n")

    results = []

    # ---- 1. Isolation Forest (unsupervised; labels are never used) ----
    print("Training Isolation Forest...")
    iso = IsolationForest(n_estimators=200, max_samples=256,
                          random_state=SEED, n_jobs=-1)
    iso.fit(fit[IF_FEATURES])
    for d in (fit, val, test):
        d["iso_score"] = -iso.score_samples(d[IF_FEATURES])   # higher = more anomalous
    results.append(evaluate("IsolationForest", val.is_fraud, val.iso_score,
                            test.is_fraud, test.iso_score))

    # ---- 2. XGBoost alone ----
    print("Training XGBoost (baseline)...")
    xgb = train_xgb(fit, val, XGB_FEATURES)
    results.append(evaluate(
        "XGBoost",
        val.is_fraud, xgb.predict_proba(val[XGB_FEATURES])[:, 1],
        test.is_fraud, xgb.predict_proba(test[XGB_FEATURES])[:, 1],
    ))

    # ---- 3. XGBoost + Isolation Forest score ----
    print("Training XGBoost + IsolationForest score...")
    xgb_iso = train_xgb(fit, val, XGB_ISO_FEATURES)
    results.append(evaluate(
        "XGBoost + IsoScore",
        val.is_fraud, xgb_iso.predict_proba(val[XGB_ISO_FEATURES])[:, 1],
        test.is_fraud, xgb_iso.predict_proba(test[XGB_ISO_FEATURES])[:, 1],
    ))

    # ---- report ----
    table = pd.DataFrame(results).round(4)
    print("\n===== RESULTS =====")
    print(table.to_string(index=False))

    print("\n===== TOP FEATURES (XGBoost + IsoScore, gain) =====")
    gain = pd.Series(xgb_iso.get_booster().get_score(importance_type="gain"))
    print(gain.sort_values(ascending=False).head(10).round(1).to_string())

    # ---- save ----
    joblib.dump(iso, ARTIFACTS / "isolation_forest.joblib")
    joblib.dump(xgb, ARTIFACTS / "xgb_baseline.joblib")
    joblib.dump(xgb_iso, ARTIFACTS / "xgb_with_iso.joblib")
    table.to_csv(ARTIFACTS / "metrics.csv", index=False)
    print("\nSaved models and metrics.csv to", ARTIFACTS)


if __name__ == "__main__":
    main()