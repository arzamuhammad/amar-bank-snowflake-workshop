"""
Generate synthetic FSI (digital bank) data for the Amar Bank Snowflake Workshop.

No external deps beyond pandas/numpy. Indonesian digital-banking context:
Amar Bank products -> Tunaiku (digital lending), Senyumku (digital savings), SMB lending.

Outputs (in ../data):
  customers.csv, loans.csv, repayments.csv, savings.csv, transactions.csv   (with header)
  transactions.parquet                                                        (file-format demo)
  savings.json                                                                (semi-structured demo)
  customers_v2_schemadrift.csv   (adds loyalty_tier, referral_code -> schema evolution demo)
  customers_badrecords.csv       (invalid NIK / out-of-range score / NULLs -> DQ demo)
  loans_incremental.csv          (a later batch with backdated + new rows -> incremental/reload demo)

Run:  python3 scripts/generate_data.py
"""
import os
import json
import random
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

SEED = 42
random.seed(SEED)
np.random.seed(SEED)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "data"))
os.makedirs(OUT, exist_ok=True)

N_CUSTOMERS = 5000
N_LOANS = 8000
N_REPAYMENTS = 40000
N_SAVINGS = 6000
N_TRANSACTIONS = 50000

PROVINCES = {
    "DKI Jakarta": ["Jakarta Selatan", "Jakarta Pusat", "Jakarta Barat", "Jakarta Timur", "Jakarta Utara"],
    "Jawa Barat": ["Bandung", "Bekasi", "Bogor", "Depok", "Cimahi"],
    "Jawa Timur": ["Surabaya", "Malang", "Sidoarjo", "Gresik"],
    "Jawa Tengah": ["Semarang", "Solo", "Magelang"],
    "Banten": ["Tangerang", "Tangerang Selatan", "Serang", "Cilegon"],
    "Bali": ["Denpasar", "Badung"],
    "Sumatera Utara": ["Medan", "Binjai"],
    "Sulawesi Selatan": ["Makassar", "Parepare"],
}
PROV_WEIGHTS = [0.34, 0.20, 0.14, 0.08, 0.10, 0.04, 0.06, 0.04]

SEGMENTS = ["Tunaiku", "Senyumku", "SMB"]
SEG_WEIGHTS = [0.55, 0.30, 0.15]
GENDERS = ["M", "F"]
FIRST_M = ["Budi", "Andi", "Agus", "Eko", "Dedi", "Rizki", "Hendra", "Bayu", "Fajar", "Joko", "Wahyu", "Yusuf"]
FIRST_F = ["Siti", "Dewi", "Ayu", "Rina", "Sri", "Putri", "Maya", "Indah", "Lestari", "Wulan", "Nur", "Fitri"]
LAST = ["Santoso", "Wijaya", "Pratama", "Saputra", "Hidayat", "Kurniawan", "Nugroho", "Permana",
        "Lestari", "Utami", "Setiawan", "Halim", "Suryadi", "Maulana", "Gunawan", "Rahmawati"]

LOAN_PRODUCTS = {
    "Tunaiku": ["Tunaiku KTA", "Tunaiku Mikro"],
    "SMB": ["SMB Modal Usaha", "SMB Invoice Financing"],
}
LOAN_STATUS = ["LANCAR", "DPD30", "DPD60", "DPD90", "LUNAS", "WRITE_OFF"]
TXN_TYPES = ["TOPUP", "TRANSFER", "PAYMENT", "WITHDRAWAL", "INTEREST", "FEE"]
CHANNELS = ["MOBILE_APP", "VA", "QRIS", "ATM_BERSAMA", "INTERNET_BANKING"]


def make_nik(valid=True):
    if not valid:
        return str(random.randint(10**10, 10**11))  # too short -> invalid
    prov = random.randint(11, 94)
    kab = random.randint(1, 99)
    kec = random.randint(1, 99)
    dd = random.randint(1, 28)
    mm = random.randint(1, 12)
    yy = random.randint(0, 99)
    seq = random.randint(1, 9999)
    return f"{prov:02d}{kab:02d}{kec:02d}{dd:02d}{mm:02d}{yy:02d}{seq:04d}"


def make_npwp():
    return f"{random.randint(10,99)}.{random.randint(100,999)}.{random.randint(100,999)}.{random.randint(1,9)}-{random.randint(100,999)}.{random.randint(100,999)}"


def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, max(delta, 1)))


# ---------------------------------------------------------------- CUSTOMERS
prov_list = list(PROVINCES.keys())
customers = []
start_reg = datetime(2021, 1, 1)
end_reg = datetime(2026, 5, 31)
for i in range(1, N_CUSTOMERS + 1):
    gender = random.choice(GENDERS)
    fn = random.choice(FIRST_M if gender == "M" else FIRST_F)
    name = f"{fn} {random.choice(LAST)}"
    prov = np.random.choice(prov_list, p=PROV_WEIGHTS)
    kota = random.choice(PROVINCES[prov])
    seg = np.random.choice(SEGMENTS, p=SEG_WEIGHTS)
    dob = rand_date(datetime(1975, 1, 1), datetime(2003, 12, 31))
    created = rand_date(start_reg, end_reg)
    cust_id = f"CUST{i:06d}"
    score = int(np.clip(np.random.normal(660, 80), 300, 850))
    income = int(np.clip(np.random.lognormal(mean=15.8, sigma=0.6), 2_500_000, 150_000_000))
    customers.append({
        "customer_id": cust_id,
        "nik": make_nik(True),
        "npwp": make_npwp() if random.random() > 0.25 else "",
        "full_name": name,
        "gender": gender,
        "birth_date": dob.strftime("%Y-%m-%d"),
        "province": prov,
        "city": kota,
        "segment": seg,
        "credit_score": score,
        "monthly_income": income,
        "phone": f"08{random.randint(1,9)}{random.randint(10000000,99999999)}",
        "email": f"{fn.lower()}{i}@example.co.id",
        "created_at": created.strftime("%Y-%m-%d %H:%M:%S"),
        "updated_at": created.strftime("%Y-%m-%d %H:%M:%S"),
    })
df_cust = pd.DataFrame(customers)

# ---------------------------------------------------------------- LOANS
loan_segments = df_cust[df_cust["segment"].isin(["Tunaiku", "SMB"])][["customer_id", "segment", "credit_score"]].reset_index(drop=True)
loans = []
for i in range(1, N_LOANS + 1):
    row = loan_segments.sample(1).iloc[0]
    seg = row["segment"]
    product = random.choice(LOAN_PRODUCTS[seg])
    plafond = int(np.random.choice([2_000_000, 5_000_000, 10_000_000, 25_000_000, 50_000_000, 100_000_000],
                                   p=[0.25, 0.25, 0.2, 0.15, 0.1, 0.05]))
    tenor = int(np.random.choice([3, 6, 12, 18, 24, 36], p=[0.2, 0.25, 0.25, 0.1, 0.1, 0.1]))
    rate = round(np.random.uniform(12, 36), 2)
    disb = rand_date(datetime(2022, 1, 1), datetime(2026, 5, 1))
    # default probability inversely related to credit score
    pdef = np.clip((720 - row["credit_score"]) / 800 + 0.05, 0.02, 0.5)
    is_default = 1 if random.random() < pdef else 0
    if is_default:
        dpd = int(np.random.choice([35, 65, 95, 120], p=[0.4, 0.3, 0.2, 0.1]))
        status = "DPD30" if dpd < 60 else ("DPD60" if dpd < 90 else ("DPD90" if dpd < 120 else "WRITE_OFF"))
    else:
        dpd = 0
        status = np.random.choice(["LANCAR", "LUNAS"], p=[0.7, 0.3])
    loans.append({
        "loan_id": f"LOAN{i:07d}",
        "customer_id": row["customer_id"],
        "product_type": product,
        "plafond": plafond,
        "tenor_months": tenor,
        "interest_rate": rate,
        "disbursed_at": disb.strftime("%Y-%m-%d"),
        "status": status,
        "dpd": dpd,
        "is_default": is_default,
        "outstanding": int(plafond * np.random.uniform(0.1, 1.0)) if status not in ("LUNAS",) else 0,
        "updated_at": (disb + timedelta(days=random.randint(0, 400))).strftime("%Y-%m-%d %H:%M:%S"),
    })
df_loans = pd.DataFrame(loans)

# ---------------------------------------------------------------- REPAYMENTS
loan_ids = df_loans["loan_id"].tolist()
repays = []
for i in range(1, N_REPAYMENTS + 1):
    lid = random.choice(loan_ids)
    due = rand_date(datetime(2022, 2, 1), datetime(2026, 5, 31))
    amount_due = int(np.random.choice([300_000, 500_000, 1_000_000, 2_000_000, 4_000_000]))
    late = random.random() < 0.18
    paid = due + timedelta(days=random.randint(1, 25)) if late else due + timedelta(days=random.randint(-3, 0))
    paid_amt = amount_due if random.random() > 0.05 else int(amount_due * np.random.uniform(0.3, 0.9))
    repays.append({
        "repayment_id": f"RPM{i:08d}",
        "loan_id": lid,
        "due_date": due.strftime("%Y-%m-%d"),
        "paid_date": paid.strftime("%Y-%m-%d"),
        "amount_due": amount_due,
        "amount_paid": paid_amt,
        "is_late": 1 if late else 0,
    })
df_repay = pd.DataFrame(repays)

# ---------------------------------------------------------------- SAVINGS
sav_customers = df_cust[df_cust["segment"].isin(["Senyumku", "Tunaiku", "SMB"])]["customer_id"].tolist()
savings = []
for i in range(1, N_SAVINGS + 1):
    cust = random.choice(sav_customers)
    acct_type = np.random.choice(["TABUNGAN", "DEPOSITO"], p=[0.8, 0.2])
    bal = int(np.clip(np.random.lognormal(mean=15.2, sigma=1.0), 50_000, 500_000_000))
    opened = rand_date(datetime(2021, 6, 1), datetime(2026, 5, 1))
    rate = round(np.random.uniform(2.5, 6.0), 2) if acct_type == "DEPOSITO" else round(np.random.uniform(0.5, 3.5), 2)
    savings.append({
        "account_id": f"ACC{i:07d}",
        "customer_id": cust,
        "account_type": acct_type,
        "balance": bal,
        "interest_rate": rate,
        "opened_at": opened.strftime("%Y-%m-%d"),
        "status": np.random.choice(["ACTIVE", "DORMANT", "CLOSED"], p=[0.85, 0.1, 0.05]),
    })
df_sav = pd.DataFrame(savings)

# ---------------------------------------------------------------- TRANSACTIONS
acct_ids = df_sav["account_id"].tolist()
txns = []
for i in range(1, N_TRANSACTIONS + 1):
    acc = random.choice(acct_ids)
    ttype = np.random.choice(TXN_TYPES, p=[0.25, 0.25, 0.2, 0.15, 0.1, 0.05])
    ch = np.random.choice(CHANNELS, p=[0.5, 0.2, 0.2, 0.05, 0.05])
    amt = int(np.clip(np.random.lognormal(mean=13.0, sigma=1.2), 10_000, 100_000_000))
    ts = rand_date(datetime(2025, 1, 1), datetime(2026, 5, 31)) + timedelta(seconds=random.randint(0, 86399))
    txns.append({
        "txn_id": f"TXN{i:09d}",
        "account_id": acc,
        "txn_type": ttype,
        "channel": ch,
        "amount": amt,
        "txn_ts": ts.strftime("%Y-%m-%d %H:%M:%S"),
    })
df_txn = pd.DataFrame(txns)


def save_csv(df, name):
    p = os.path.join(OUT, name)
    df.to_csv(p, index=False)
    print(f"  {name:38s} {len(df):>7,} rows")


print(f"Writing data to: {OUT}")
save_csv(df_cust, "customers.csv")
save_csv(df_loans, "loans.csv")
save_csv(df_repay, "repayments.csv")
save_csv(df_sav, "savings.csv")
save_csv(df_txn, "transactions.csv")

# Parquet + JSON for file-format / semi-structured demos
df_txn.to_parquet(os.path.join(OUT, "transactions.parquet"), index=False)
print(f"  transactions.parquet                   {len(df_txn):>7,} rows")
df_sav.to_json(os.path.join(OUT, "savings.json"), orient="records", lines=True)
print(f"  savings.json (ndjson)                  {len(df_sav):>7,} rows")

# ---------------------------------------------------------------- SCENARIO: schema drift v2
df_v2 = df_cust.sample(500, random_state=SEED).copy()
df_v2["loyalty_tier"] = np.random.choice(["BRONZE", "SILVER", "GOLD", "PLATINUM"], size=len(df_v2), p=[0.5, 0.3, 0.15, 0.05])
df_v2["referral_code"] = ["REF" + str(random.randint(100000, 999999)) for _ in range(len(df_v2))]
save_csv(df_v2, "customers_v2_schemadrift.csv")

# ---------------------------------------------------------------- SCENARIO: bad records (DQ demo)
bad = df_cust.sample(40, random_state=7).copy().reset_index(drop=True)
bad.loc[0:9, "nik"] = bad.loc[0:9, "nik"].str.slice(0, 10)        # invalid NIK length
bad.loc[10:19, "credit_score"] = np.random.choice([0, 1200, 9999, -5], 10)  # out of range
bad.loc[20:29, "email"] = ""                                       # null/empty email
bad.loc[30:39, "province"] = ""                                    # null province
# create a few duplicate customer_id
bad.loc[35:39, "customer_id"] = bad.loc[0, "customer_id"]
save_csv(bad, "customers_badrecords.csv")

# ---------------------------------------------------------------- SCENARIO: loans incremental (backdated + new)
inc = df_loans.sample(300, random_state=11).copy()
inc["status"] = "LUNAS"                                             # updates to existing loans
inc["outstanding"] = 0
inc["updated_at"] = "2026-06-01 09:00:00"
new_rows = []
for j in range(1, 101):                                            # genuinely new loans
    row = loan_segments.sample(1).iloc[0]
    seg = row["segment"]
    new_rows.append({
        "loan_id": f"LOAN9{j:06d}",
        "customer_id": row["customer_id"],
        "product_type": random.choice(LOAN_PRODUCTS[seg]),
        "plafond": 10_000_000, "tenor_months": 12, "interest_rate": 24.0,
        "disbursed_at": "2026-06-01", "status": "LANCAR", "dpd": 0,
        "is_default": 0, "outstanding": 10_000_000, "updated_at": "2026-06-01 10:00:00",
    })
df_inc = pd.concat([inc, pd.DataFrame(new_rows)], ignore_index=True)
save_csv(df_inc, "loans_incremental.csv")

print("\nDone. Summary:")
print(f"  customers      {len(df_cust):>7,}")
print(f"  loans          {len(df_loans):>7,}  (default rate {df_loans['is_default'].mean():.1%})")
print(f"  repayments     {len(df_repay):>7,}  (late rate {df_repay['is_late'].mean():.1%})")
print(f"  savings        {len(df_sav):>7,}")
print(f"  transactions   {len(df_txn):>7,}")
