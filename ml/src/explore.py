import pandas as pd

from config import TRAIN_CSV, TEST_CSV
from download_data import ensure_data

ensure_data()

pd.set_option("display.width", 140)
pd.set_option("display.max_columns", 30)


def load(path):
    # first column in the CSV is an unnamed index
    return pd.read_csv(path, index_col=0, parse_dates=["trans_date_trans_time"])


train, test = load(TRAIN_CSV), load(TEST_CSV)

for name, df in [("TRAIN", train), ("TEST", test)]:
    print(f"\n===== {name} =====")
    print("rows:", len(df))
    print("date range:", df.trans_date_trans_time.min(), "->", df.trans_date_trans_time.max())
    print("fraud count:", int(df.is_fraud.sum()), f"({df.is_fraud.mean():.3%})")

print("\n===== COLUMNS =====")
print(train.dtypes)

print("\n===== FRAUD RATE BY CATEGORY (train) =====")
cat = train.groupby("category").is_fraud.agg(["count", "sum", "mean"])
print(cat.sort_values("mean", ascending=False))

print("\n===== AMOUNT: LEGIT vs FRAUD (train) =====")
print(train.groupby("is_fraud").amt.describe())

print("\n===== FRAUD RATE BY HOUR (train) =====")
hour = train.groupby(train.trans_date_trans_time.dt.hour).is_fraud.mean()
print(hour.round(4).to_string())

print("\n===== CARD HISTORY (train) =====")
per_card = train.groupby("cc_num").size()
print("unique cards:", per_card.shape[0])
print(per_card.describe())