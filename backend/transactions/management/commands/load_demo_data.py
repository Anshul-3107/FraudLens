import json
import random
from decimal import Decimal
from pathlib import Path

import pandas as pd
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from transactions.models import Alert, Card, Transaction

BATCH = 5000
CSV_COLUMNS = [
    "trans_date_trans_time", "cc_num", "merchant", "category", "amt",
    "lat", "long", "merch_lat", "merch_long", "trans_num", "is_fraud",
]


def chunks(items, size):
    items = list(items)
    for i in range(0, len(items), size):
        yield items[i:i + size]


def read_cards(path, chosen=None):
    """Read the CSV; if `chosen` is given keep only those cards. Adds a UTC timestamp column."""
    df = pd.read_csv(path, usecols=CSV_COLUMNS)
    if chosen is not None:
        df = df[df["cc_num"].isin(chosen)].copy()
    df["ts"] = pd.to_datetime(df["trans_date_trans_time"], utc=True)
    return df


class Command(BaseCommand):
    help = (
        "Load simulated cards, transactions and ML alerts from the ml/ folder into the "
        "database. Safe to run more than once."
    )

    def add_arguments(self, parser):
        parser.add_argument("--cards", type=int, default=100,
                            help="Number of cards to load (random sample, seed 42). Default 100.")
        parser.add_argument("--all", action="store_true",
                            help="Load every card (about 555k test-period transactions).")
        parser.add_argument("--owner", default=None, help="Username that should own the loaded cards.")
        parser.add_argument("--history", action="store_true",
                            help="Also load the training-period transactions (Jan 2019 - Jun 2020) "
                                 "for the chosen cards, so live scoring sees each card's full history. "
                                 "No alerts are created for them. Avoid combining with --all.")

    def handle(self, *args, **opts):
        ml_data = Path(settings.ML_PROCESSED_DIR).parent
        test_csv = ml_data / "raw" / "fraudTest.csv"
        train_csv = ml_data / "raw" / "fraudTrain.csv"
        alerts_path = Path(settings.ML_PROCESSED_DIR) / "test_alerts.parquet"
        threshold_path = Path(settings.ML_ARTIFACTS_DIR) / "threshold.json"
        required = [test_csv, alerts_path, threshold_path] + ([train_csv] if opts["history"] else [])
        for path in required:
            if not path.exists():
                raise CommandError(f"Missing file: {path}. Run the ML pipeline first.")

        owner = None
        if opts["owner"]:
            User = get_user_model()
            try:
                owner = User.objects.get(username=opts["owner"])
            except User.DoesNotExist:
                raise CommandError(f"No user named '{opts['owner']}'. Create one with createsuperuser.")

        threshold = json.loads(threshold_path.read_text())["threshold"]

        # ---- choose cards (from the test file) ----
        self.stdout.write("Reading test-period data...")
        all_cards = sorted(pd.read_csv(test_csv, usecols=["cc_num"])["cc_num"].unique())
        if opts["all"]:
            chosen = all_cards
        else:
            chosen = random.Random(42).sample(all_cards, min(opts["cards"], len(all_cards)))
        test_df = read_cards(test_csv, chosen)
        self.stdout.write(f"Selected {len(chosen)} cards, {len(test_df):,} test-period transactions.")

        # ---- cards ----
        home = test_df.groupby("cc_num")[["lat", "long"]].first()
        for cc in chosen:
            card, _ = Card.objects.get_or_create(
                card_ref=str(cc),
                defaults={
                    "label": f"Card ending {str(cc)[-4:]}",
                    "home_lat": float(home.loc[cc, "lat"]),
                    "home_long": float(home.loc[cc, "long"]),
                },
            )
            if owner is not None and card.owner_id != owner.id:
                card.owner = owner
                card.save(update_fields=["owner"])
        card_id = dict(Card.objects.filter(card_ref__in=[str(c) for c in chosen])
                       .values_list("card_ref", "id"))

        # ---- transactions ----
        if opts["history"]:
            self.stdout.write("Reading training-period history (this file is large)...")
            history_df = read_cards(train_csv, chosen)
            self.stdout.write(f"Loading {len(history_df):,} history transactions...")
            self.import_transactions(history_df, card_id)
        self.stdout.write("Loading test-period transactions...")
        self.import_transactions(test_df, card_id)

        # ---- alerts (test period only) ----
        alerts = pd.read_parquet(alerts_path)
        alerts = alerts[alerts["trans_num"].isin(set(test_df["trans_num"]))]

        trans_id = {}
        for part in chunks(card_id.values(), 500):
            trans_id.update(
                Transaction.objects.filter(card_id__in=part).values_list("trans_ref", "id")
            )
        to_create = [
            Alert(
                transaction_id=trans_id[a.trans_num],
                score=float(a.score),
                threshold=threshold,
                reasons=json.loads(a.reasons),
            )
            for a in alerts.itertuples(index=False)
        ]
        for part in chunks(to_create, BATCH):
            Alert.objects.bulk_create(part, ignore_conflicts=True)

        # ---- summary ----
        self.stdout.write(self.style.SUCCESS(
            f"\nDone. Database now holds {Card.objects.count()} cards, "
            f"{Transaction.objects.count():,} transactions, {Alert.objects.count():,} alerts."
        ))
        self.stdout.write(
            f"Test period: {int(test_df['is_fraud'].sum())} true frauds, {len(alerts)} alerts raised "
            f"(threshold {threshold}), {int(alerts['is_fraud'].sum())} of them real fraud."
        )
        if owner:
            self.stdout.write(f"Cards assigned to user '{owner.username}'.")

    def import_transactions(self, df, card_id):
        batch, total = [], 0
        for row in df.itertuples(index=False):
            batch.append(Transaction(
                trans_ref=row.trans_num,
                card_id=card_id[str(row.cc_num)],
                occurred_at=row.ts.to_pydatetime(),
                merchant=row.merchant.removeprefix("fraud_"),
                category=row.category,
                amount=Decimal(f"{row.amt:.2f}"),
                merch_lat=float(row.merch_lat),
                merch_long=float(row.merch_long),
                source=Transaction.Source.SIMULATED,
                is_fraud_label=bool(row.is_fraud),
            ))
            if len(batch) >= BATCH:
                Transaction.objects.bulk_create(batch, ignore_conflicts=True)
                total += len(batch)
                batch = []
                self.stdout.write(f"  {total:,} processed")
        if batch:
            Transaction.objects.bulk_create(batch, ignore_conflicts=True)