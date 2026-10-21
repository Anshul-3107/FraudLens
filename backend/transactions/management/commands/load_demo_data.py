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


class Command(BaseCommand):
    help = (
        "Load simulated cards, transactions and ML alerts (test period) from the "
        "ml/ folder into the database. Safe to run more than once."
    )

    def add_arguments(self, parser):
        parser.add_argument("--cards", type=int, default=100,
                            help="Number of cards to load (random sample, seed 42). Default 100.")
        parser.add_argument("--all", action="store_true", help="Load every card (about 555k transactions).")
        parser.add_argument("--owner", default=None,
                            help="Username that should own the loaded cards.")

    def handle(self, *args, **opts):
        ml_data = Path(settings.ML_PROCESSED_DIR).parent
        csv_path = ml_data / "raw" / "fraudTest.csv"
        alerts_path = Path(settings.ML_PROCESSED_DIR) / "test_alerts.parquet"
        threshold_path = Path(settings.ML_ARTIFACTS_DIR) / "threshold.json"
        for path in (csv_path, alerts_path, threshold_path):
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

        # ---- read and choose cards ----
        self.stdout.write("Reading dataset...")
        df = pd.read_csv(csv_path, usecols=CSV_COLUMNS)
        all_cards = sorted(df["cc_num"].unique())
        if opts["all"]:
            chosen = all_cards
        else:
            chosen = random.Random(42).sample(all_cards, min(opts["cards"], len(all_cards)))
        df = df[df["cc_num"].isin(chosen)].copy()
        df["ts"] = pd.to_datetime(df["trans_date_trans_time"], utc=True)
        self.stdout.write(f"Selected {len(chosen)} cards, {len(df):,} transactions.")

        # ---- cards ----
        home = df.groupby("cc_num")[["lat", "long"]].first()
        for cc in chosen:
            card, created = Card.objects.get_or_create(
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
                self.stdout.write(f"  {total:,} transactions processed")
        if batch:
            Transaction.objects.bulk_create(batch, ignore_conflicts=True)
            total += len(batch)

        # ---- alerts (only for the transactions we loaded) ----
        alerts = pd.read_parquet(alerts_path)
        alerts = alerts[alerts["trans_num"].isin(set(df["trans_num"]))]

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
        n_fraud = int(df["is_fraud"].sum())
        n_alerts = len(alerts)
        caught = int(alerts["is_fraud"].sum())
        self.stdout.write(self.style.SUCCESS(
            f"\nDone. Database now holds {Card.objects.count()} cards, "
            f"{Transaction.objects.count():,} transactions, {Alert.objects.count():,} alerts."
        ))
        self.stdout.write(
            f"This load: {n_fraud} true frauds, {n_alerts} alerts raised "
            f"(threshold {threshold}), {caught} of the alerts are real fraud."
        )
        if owner:
            self.stdout.write(f"Cards assigned to user '{owner.username}'.")