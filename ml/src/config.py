from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]   # .../FraudLens/ml
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
ARTIFACTS = ROOT / "artifacts"

TRAIN_CSV = RAW / "fraudTrain.csv"
TEST_CSV = RAW / "fraudTest.csv"
FEATURES_PARQUET = PROCESSED / "features.parquet"