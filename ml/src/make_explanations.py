import json

import joblib
import matplotlib

matplotlib.use("Agg")  # save plots to files, no window
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import shap

from config import ARTIFACTS, PROCESSED
from explain import explain, shap_contribs
from train import SEED, XGB_ISO_FEATURES
from tune_threshold import load_scored


def main():
    _, test = load_scored()
    model = joblib.load(ARTIFACTS / "xgb_with_iso.joblib")
    with open(ARTIFACTS / "threshold.json") as f:
        thr = json.load(f)["threshold"]

    # ---- global SHAP: which features matter overall ----
    sample = test.sample(20_000, random_state=SEED)
    X = sample[XGB_ISO_FEATURES]
    contribs = shap_contribs(model, X)

    # sanity check: SHAP values must add up to the model's own prediction
    proba = model.predict_proba(X)[:, 1]
    rebuilt = 1 / (1 + np.exp(-contribs.sum(axis=1)))
    diff = float(np.abs(proba - rebuilt).max())
    print(f"SHAP additivity check, max difference: {diff:.6f} ({'OK' if diff < 1e-3 else 'PROBLEM'})")

    mean_abs = pd.Series(np.abs(contribs[:, :-1]).mean(axis=0), index=XGB_ISO_FEATURES)
    print("\n===== MEAN |SHAP| (top 10 features) =====")
    print(mean_abs.sort_values(ascending=False).head(10).round(3).to_string())

    shap.summary_plot(contribs[:, :-1], X, show=False, max_display=15)
    plt.tight_layout()
    plt.savefig(ARTIFACTS / "shap_summary.png", dpi=150, bbox_inches="tight")
    plt.close()
    print("\nSaved", ARTIFACTS / "shap_summary.png")

    # ---- example explanations ----
    flagged = test[test["score"] >= thr]
    examples = pd.concat([
        flagged[flagged["is_fraud"] == 1].sample(3, random_state=SEED),
        flagged[flagged["is_fraud"] == 0].sample(3, random_state=SEED),
    ])
    example_reasons = explain(model, examples[XGB_ISO_FEATURES])

    print("\n===== EXAMPLE ALERTS =====")
    for (_, row), reasons in zip(examples.iterrows(), example_reasons):
        verdict = "ACTUAL FRAUD" if row["is_fraud"] == 1 else "actually legit (false alert)"
        print(f"\n${row['amt']:,.2f} | {row['category']} | score {row['score']:.2f} | {verdict}")
        for r in reasons:
            print(f"   - {r['text']}  (+{r['impact']})")

    # ---- explain every flagged test transaction, save for the backend ----
    print(f"\nExplaining all {len(flagged):,} flagged transactions...")
    all_reasons = explain(model, flagged[XGB_ISO_FEATURES])

    keep = ["trans_num", "trans_date_trans_time", "cc_num", "merchant",
            "category", "amt", "is_fraud", "score"]
    alerts = flagged[keep].copy()
    alerts["reasons"] = [json.dumps(r) for r in all_reasons]
    PROCESSED.mkdir(parents=True, exist_ok=True)
    alerts.to_parquet(PROCESSED / "test_alerts.parquet", index=False)
    print("Saved", PROCESSED / "test_alerts.parquet")


if __name__ == "__main__":
    main()