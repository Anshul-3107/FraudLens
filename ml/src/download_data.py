import shutil
from pathlib import Path

import kagglehub

from config import RAW, TRAIN_CSV, TEST_CSV

DATASET = "kartik2112/fraud-detection"
FILES = ("fraudTrain.csv", "fraudTest.csv")


def ensure_data():
    """Download the dataset into ml/data/raw if it isn't there yet."""
    if TRAIN_CSV.exists() and TEST_CSV.exists():
        return

    RAW.mkdir(parents=True, exist_ok=True)
    print("Downloading dataset from Kaggle...")
    cache_dir = Path(kagglehub.dataset_download(DATASET))

    for name in FILES:
        src = next(cache_dir.rglob(name))   # find the file even if nested
        shutil.copy(src, RAW / name)
    print(f"Done. Files saved to {RAW}")


if __name__ == "__main__":
    ensure_data()