from django.core.management.base import BaseCommand, CommandError

from transactions.models import Card, UserBehaviorProfile
from transactions.personal_ml_service import train_personal_model_for_card


class Command(BaseCommand):
    help = "Trains personalized behavioral Isolation Forest model(s) for user cards."

    def add_arguments(self, parser):
        parser.add_argument(
            "--card-id",
            type=int,
            help="Specific Card ID to train personal behavioral model for.",
        )
        parser.add_argument(
            "--all-eligible",
            action="store_true",
            help="Train personal models for all cards having at least 20 transactions.",
        )

    def handle(self, *args, **options):
        card_id = options.get("card_id")
        all_eligible = options.get("all_eligible")

        if not card_id and not all_eligible:
            self.stdout.write(
                self.style.WARNING(
                    "Please specify either --card-id <ID> or --all-eligible to run personal model training."
                )
            )
            return

        if card_id:
            try:
                card = Card.objects.get(id=card_id)
            except Card.DoesNotExist:
                raise CommandError(f"Card with ID {card_id} does not exist.")

            self.stdout.write(f"Training personal model for card: {card.label} (ID: {card.id})...")
            res = train_personal_model_for_card(card.id)
            if res.get("success"):
                self.stdout.write(
                    self.style.SUCCESS(
                        f"✓ Success! Trained on {res['txns_trained']} transactions. "
                        f"Artifact saved to {res['artifact_path']}. "
                        f"Graduated to Phase {res['graduation_phase']}."
                    )
                )
            else:
                self.stdout.write(self.style.ERROR(f"✗ Failed: {res.get('error')}"))

        elif all_eligible:
            cards = Card.objects.all()
            trained_count = 0
            for card in cards:
                txn_count = card.transactions.count()
                if txn_count >= 20:
                    self.stdout.write(f"Processing card: {card.label} ({txn_count} txns)...")
                    res = train_personal_model_for_card(card.id)
                    if res.get("success"):
                        trained_count += 1
                        self.stdout.write(
                            self.style.SUCCESS(
                                f"  ✓ Trained on {res['txns_trained']} txns. Phase {res['graduation_phase']}."
                            )
                        )
                    else:
                        self.stdout.write(self.style.WARNING(f"  - Skipped: {res.get('error')}"))

            self.stdout.write(self.style.SUCCESS(f"\nDone! Trained personal models for {trained_count} cards."))
