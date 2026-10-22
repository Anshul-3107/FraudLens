import random
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from transactions.ml_service import get_bundle, score_transaction
from transactions.models import Transaction

TEST_START = datetime(2020, 6, 21, 12, 14, 25, tzinfo=timezone.utc)   # first test-period transaction
SCORE_TOLERANCE = 1e-4
FEATURE_TOLERANCE = 1e-6


class Command(BaseCommand):
    help = "Check that live scoring reproduces the offline ML pipeline's features and scores."

    def add_arguments(self, parser):
        parser.add_argument("--n", type=int, default=300, help="Transactions to check (default 300).")

    def handle(self, *args, **opts):
        processed = Path(settings.ML_PROCESSED_DIR)
        predictions_path = processed / "test_predictions.parquet"
        features_path = processed / "features.parquet"
        for path in (predictions_path, features_path):
            if not path.exists():
                raise CommandError(f"Missing file: {path}")

        if not Transaction.objects.filter(occurred_at__lt=TEST_START).exists():
            raise CommandError(
                "No training-period history in the database. Run: "
                "python manage.py load_demo_data --history"
            )

        bundle = get_bundle()
        offline = pd.read_parquet(predictions_path, columns=["trans_num", "score"]) \
            .set_index("trans_num")["score"]

        pool = list(Transaction.objects.filter(occurred_at__gte=TEST_START).values_list("id", flat=True))
        ids = random.Random(7).sample(pool, min(opts["n"], len(pool)))
        transactions = Transaction.objects.filter(id__in=ids).select_related("card")
        self.stdout.write(f"Re-scoring {len(ids)} stored transactions...")

        results, feature_rows = [], {}
        for i, t in enumerate(transactions, 1):
            out = score_transaction(
                card=t.card, occurred_at=t.occurred_at, merchant=t.merchant,
                category=t.category, amount=t.amount,
                merch_lat=t.merch_lat, merch_long=t.merch_long,
            )
            feature_rows[t.trans_ref] = out["features"]
            results.append({
                "ref": t.trans_ref,
                "offline": float(offline[t.trans_ref]),
                "live": out["score"],
            })
            if i % 100 == 0:
                self.stdout.write(f"  {i} done")

        res = pd.DataFrame(results)
        res["diff"] = (res["live"] - res["offline"]).abs()
        thr = bundle.threshold
        agree = ((res["live"] >= thr) == (res["offline"] >= thr)).mean()

        # ---- feature-by-feature comparison ----
        feature_names = bundle.features.FEATURES
        offline_feats = pd.read_parquet(
            features_path, columns=["trans_num"] + feature_names,
            filters=[("trans_num", "in", list(feature_rows))],
        ).set_index("trans_num")
        live_feats = pd.DataFrame.from_dict(feature_rows, orient="index")[feature_names].astype(float)
        feat_diff = (live_feats - offline_feats.loc[live_feats.index, feature_names].astype(float)).abs().max()

        self.stdout.write("\n===== FEATURES: largest difference, live vs offline =====")
        for name, value in feat_diff.items():
            mark = "" if value <= FEATURE_TOLERANCE else "   <-- MISMATCH"
            self.stdout.write(f"  {name:24s} {value:.8f}{mark}")

        self.stdout.write("\n===== SCORES =====")
        self.stdout.write(f"  checked:                 {len(res)}")
        self.stdout.write(f"  max difference:          {res['diff'].max():.8f}")
        self.stdout.write(f"  mean difference:         {res['diff'].mean():.8f}")
        self.stdout.write(f"  within {SCORE_TOLERANCE}:          {(res['diff'] <= SCORE_TOLERANCE).mean():.1%}")
        self.stdout.write(f"  same alert decision:     {agree:.1%} (threshold {thr})")

        worst = res.sort_values("diff", ascending=False).head(3)
        if worst["diff"].iloc[0] > SCORE_TOLERANCE:
            self.stdout.write("\n  Largest differences:")
            for r in worst.itertuples():
                self.stdout.write(f"    {r.ref[:12]}  offline {r.offline:.6f}  live {r.live:.6f}")

        ok = res["diff"].max() <= SCORE_TOLERANCE and agree == 1.0
        if ok:
            self.stdout.write(self.style.SUCCESS("\nPARITY OK: live scoring reproduces the offline pipeline."))
        else:
            self.stdout.write(self.style.ERROR(
                "\nMISMATCH: see the feature table above for which feature differs."
            ))