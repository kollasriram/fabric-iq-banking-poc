# Northwind Financial — synthetic data generator (stdlib only, deterministic)
#
# Emits two SOURCE SYSTEMS so the ontology has real entity-resolution work to do:
#   payments/*  -> customerId (P-####)   (Subject Area A: Payments & Deposits)
#   lending/*   -> borrowerId (B-####)   (Subject Area B: Lending & Credit Risk)
# An overlap set of people appear in BOTH systems with the SAME name+email but
# different IDs, so identity resolution (email/name) must unify them.
#
# Seeded fraud so every rule/graph/RTI demo has hits:
#   - cross-border high-value ( > 10000 and geo != home country )
#   - card velocity ( >=3 merchants in < 5 min )
#   - impossible travel ( same card, far geos, short gap )
#   - fraud ring ( many cards sharing a small merchant set -> community detection )
#
# Usage:  python generate.py --scale demo --seed 42 --out ./out
import argparse, csv, os, random, hashlib
from datetime import datetime, timedelta

REF = datetime(2026, 9, 19, 12, 0, 0)  # "now" anchor

COUNTRIES = ["US", "CA", "GB", "MX", "DE", "IN", "BR", "NG", "RU", "SG"]
HOME_WEIGHTS = [60, 12, 8, 6, 4, 4, 2, 2, 1, 1]  # most customers are US/CA/GB
SEGMENTS = ["Mass", "Affluent", "SmallBiz", "Private"]
REGIONS = ["Northeast", "Southeast", "Midwest", "West", "Southwest"]
PRODUCTS = [("PRD-CHK", "Everyday Checking", "Checking"),
            ("PRD-SAV", "High-Yield Savings", "Savings"),
            ("PRD-STU", "Student Checking", "Checking"),
            ("PRD-BIZ", "Business Checking", "Checking")]
NETWORKS = ["VISA", "MC", "AMEX"]
CHANNELS = ["POS", "ECOM", "ATM", "MOBILE"]
MCCS = [("5411", "Grocery"), ("5812", "Restaurants"), ("5541", "Fuel"),
        ("5999", "Retail"), ("4829", "MoneyTransfer"), ("7995", "Gambling"),
        ("5967", "DirectMarketing"), ("6011", "ATM")]
LOAN_TYPES = ["Auto", "Personal", "HomeEquity", "SmallBiz"]
GRADES = ["A", "B", "C", "D", "E"]

FIRST = ["James","Mary","Robert","Patricia","John","Jennifer","Michael","Linda",
         "David","Elizabeth","William","Barbara","Richard","Susan","Joseph","Jessica",
         "Thomas","Sarah","Chris","Karen","Daniel","Nancy","Matthew","Lisa","Priya",
         "Wei","Ahmed","Sofia","Diego","Yuki","Omar","Fatima","Ivan","Chen","Aisha"]
LAST = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis",
        "Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson",
        "Patel","Nguyen","Kim","Okafor","Rossi","Muller","Ivanov","Chen","Khan","Silva"]

SCALES = {
    "demo":  dict(persons=2000, overlap=600, merchants=50, txns=50000, loans=700, rings=4),
    "small": dict(persons=500,  overlap=150, merchants=30, txns=8000,  loans=200, rings=2),
    "large": dict(persons=20000, overlap=6000, merchants=200, txns=1000000, loans=6000, rings=12),
}


def wchoice(rng, items, weights):
    return rng.choices(items, weights=weights, k=1)[0]


def dt_iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%S")


def write_csv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  wrote {os.path.basename(path):28} {len(rows):>8} rows")


def gen(scale, seed, out):
    cfg = SCALES[scale]
    rng = random.Random(seed)
    pay_dir = os.path.join(out, "payments")
    len_dir = os.path.join(out, "lending")
    os.makedirs(pay_dir, exist_ok=True)
    os.makedirs(len_dir, exist_ok=True)

    # ---- People (ground truth) ----
    people = []
    for i in range(cfg["persons"]):
        fn = rng.choice(FIRST); ln = rng.choice(LAST)
        name = f"{fn} {ln}"
        email = f"{fn.lower()}.{ln.lower()}{i}@example.com"
        people.append(dict(pid=i, name=name, email=email,
                           segment=rng.choice(SEGMENTS), region=rng.choice(REGIONS),
                           home=wchoice(rng, COUNTRIES, HOME_WEIGHTS)))

    # payments customers = all people; lending borrowers = overlap subset + some new-only
    pay_people = people
    overlap_ids = set(rng.sample(range(cfg["persons"]), cfg["overlap"]))
    lend_only_n = cfg["overlap"] // 2
    lend_people = [people[i] for i in overlap_ids]
    for j in range(lend_only_n):  # borrowers with no payments relationship
        fn = rng.choice(FIRST); ln = rng.choice(LAST)
        lend_people.append(dict(pid=100000 + j, name=f"{fn} {ln}",
                                email=f"{fn.lower()}.{ln.lower()}{100000+j}@example.com",
                                segment=rng.choice(SEGMENTS), region=rng.choice(REGIONS),
                                home=wchoice(rng, COUNTRIES, HOME_WEIGHTS)))

    # ---- PAYMENTS source ----
    cust_rows, cust_by_pid = [], {}
    for idx, p in enumerate(pay_people):
        cid = f"P-{idx:05d}"
        cust_by_pid[p["pid"]] = cid
        risk = round(rng.uniform(0.0, 1.0), 3)
        cust_rows.append([cid, p["name"], p["email"], p["segment"], p["region"], p["home"], risk])
    write_csv(os.path.join(pay_dir, "customers.csv"),
              ["customerId", "name", "email", "segment", "region", "homeCountry", "riskScore"], cust_rows)

    write_csv(os.path.join(pay_dir, "products.csv"),
              ["productId", "name", "family"], [[a, b, c] for a, b, c in PRODUCTS])

    branches = [[f"BR-{i:03d}", f"{rng.choice(['Downtown','Uptown','Lakeside','Central','Harbor'])} Branch {i}",
                 rng.choice(REGIONS)] for i in range(1, 21)]
    write_csv(os.path.join(pay_dir, "branches.csv"), ["branchId", "name", "region"], branches)

    acct_rows, acct_by_cust = [], {}
    aidx = 0
    for cid in [r[0] for r in cust_rows]:
        for _ in range(rng.choices([1, 2, 3], weights=[60, 30, 10])[0]):
            aid = f"AC-{aidx:06d}"; aidx += 1
            prod = rng.choice(PRODUCTS)[0]
            bal = round(rng.uniform(50, 85000), 2)
            opened = REF - timedelta(days=rng.randint(30, 3000))
            status = wchoice(rng, ["Active", "Dormant", "Closed"], [90, 7, 3])
            acct_rows.append([aid, cid, prod, rng.choice(branches)[0], bal, status, opened.strftime("%Y-%m-%d")])
            acct_by_cust.setdefault(cid, []).append(aid)
    write_csv(os.path.join(pay_dir, "accounts.csv"),
              ["accountId", "customerId", "productId", "branchId", "balance", "status", "openedDate"], acct_rows)

    card_rows, cards = [], []
    cidx = 0
    for aid, cid in [(r[0], r[1]) for r in acct_rows]:
        if rng.random() < 0.85:
            card = f"CD-{cidx:06d}"; cidx += 1
            issued = REF - timedelta(days=rng.randint(10, 1500))
            card_rows.append([card, aid, cid, rng.choice(NETWORKS),
                              wchoice(rng, ["Active", "Blocked", "Expired"], [92, 3, 5]),
                              issued.strftime("%Y-%m-%d")])
            cards.append(dict(card=card, aid=aid, cid=cid))
    write_csv(os.path.join(pay_dir, "cards.csv"),
              ["cardId", "accountId", "customerId", "network", "status", "issuedDate"], card_rows)

    merch_rows, merchants = [], []
    for i in range(cfg["merchants"]):
        mcc, cat = rng.choice(MCCS)
        country = wchoice(rng, COUNTRIES, HOME_WEIGHTS)
        risk = 1 if (cat in ("Gambling", "MoneyTransfer", "DirectMarketing") and rng.random() < 0.6) else 0
        mid = f"MER-{i:04d}"
        merch_rows.append([mid, f"{cat} Store {i}", cat, mcc, country, risk])
        merchants.append(dict(mid=mid, cat=cat, mcc=mcc, country=country, risk=risk))
    write_csv(os.path.join(pay_dir, "merchants.csv"),
              ["merchantId", "name", "category", "mcc", "country", "riskFlag"], merch_rows)

    # ---- Transactions (normal + seeded fraud) ----
    home_by_cid = {r[0]: r[5] for r in cust_rows}
    txn_rows, fraud_txns = [], []
    tix = 0

    def new_txn(card, ts, amount, merch, geo, channel, is_fraud=0, ftype=""):
        nonlocal tix
        tid = f"TX-{tix:08d}"; tix += 1
        txn_rows.append([tid, card["card"], card["aid"], card["cid"], merch["mid"],
                         round(amount, 2), "USD", dt_iso(ts), channel, geo, merch["mcc"],
                         is_fraud, ftype])
        if is_fraud:
            fraud_txns.append((tid, card, ftype, ts))
        return tid

    normal_n = max(0, cfg["txns"] - int(cfg["txns"] * 0.06))
    for _ in range(normal_n):
        card = rng.choice(cards)
        merch = rng.choice(merchants)
        ts = REF - timedelta(days=rng.randint(0, 120), seconds=rng.randint(0, 86399))
        amt = round(abs(rng.gauss(60, 90)) + 2, 2)
        geo = home_by_cid[card["cid"]] if rng.random() < 0.95 else rng.choice(COUNTRIES)
        new_txn(card, ts, amt, merch, geo, rng.choice(CHANNELS))

    # cross-border high-value
    for _ in range(int(cfg["txns"] * 0.010)):
        card = rng.choice(cards)
        home = home_by_cid[card["cid"]]
        foreign = rng.choice([c for c in COUNTRIES if c != home])
        merch = rng.choice([m for m in merchants if m["country"] == foreign] or merchants)
        ts = REF - timedelta(days=rng.randint(0, 120), seconds=rng.randint(0, 86399))
        new_txn(card, ts, rng.uniform(10001, 45000), merch, foreign, "ECOM", 1, "CrossBorderHighValue")

    # card velocity: >=3 merchants within 5 min
    for _ in range(int(cfg["txns"] * 0.004)):
        card = rng.choice(cards)
        base = REF - timedelta(days=rng.randint(0, 120), seconds=rng.randint(0, 80000))
        ms = rng.sample(merchants, k=min(4, len(merchants)))
        for k, merch in enumerate(ms):
            new_txn(card, base + timedelta(seconds=k * 55), rng.uniform(20, 400),
                    merch, home_by_cid[card["cid"]], "POS", 1, "Velocity")

    # impossible travel: two far geos, short gap
    for _ in range(int(cfg["txns"] * 0.003)):
        card = rng.choice(cards)
        base = REF - timedelta(days=rng.randint(0, 120), seconds=rng.randint(0, 80000))
        new_txn(card, base, rng.uniform(30, 500), rng.choice(merchants), "US", "POS", 1, "ImpossibleTravel")
        new_txn(card, base + timedelta(minutes=20), rng.uniform(30, 500), rng.choice(merchants), "SG", "POS", 1, "ImpossibleTravel")

    # fraud rings: sets of cards sharing a small merchant set (community detection)
    for ring in range(cfg["rings"]):
        ring_cards = rng.sample(cards, k=rng.randint(4, 8))
        ring_merch = rng.sample(merchants, k=rng.randint(2, 3))
        for card in ring_cards:
            for _ in range(rng.randint(3, 6)):
                merch = rng.choice(ring_merch)
                ts = REF - timedelta(days=rng.randint(0, 60), seconds=rng.randint(0, 86399))
                new_txn(card, ts, rng.uniform(200, 3000), merch,
                        home_by_cid[card["cid"]], "ECOM", 1, f"Ring-{ring}")

    write_csv(os.path.join(pay_dir, "transactions.csv"),
              ["txnId", "cardId", "accountId", "customerId", "merchantId", "amount", "currency",
               "timestamp", "channel", "geoCountry", "mcc", "isFraud", "fraudType"], txn_rows)

    # ---- Fraud alerts derived from fraud txns ----
    alert_rows = []
    sev_map = {"CrossBorderHighValue": "High", "Velocity": "High",
               "ImpossibleTravel": "Critical", "default": "Medium"}
    for i, (tid, card, ftype, ts) in enumerate(fraud_txns):
        if ftype.startswith("Ring"):
            sev = "Medium"; atype = "RingActivity"
        else:
            sev = sev_map.get(ftype, "Medium"); atype = ftype
        alert_rows.append([f"AL-{i:07d}", tid, card["card"], card["cid"], atype, sev,
                           wchoice(rng, ["Open", "Investigating", "Closed"], [55, 25, 20]),
                           dt_iso(ts + timedelta(seconds=rng.randint(1, 120)))])
    write_csv(os.path.join(pay_dir, "fraud_alerts.csv"),
              ["alertId", "txnId", "cardId", "customerId", "type", "severity", "status", "raisedAt"], alert_rows)

    # ---- LENDING source (borrowerId; overlap people share name+email) ----
    lend_rows, borrower_ids = [], []
    for idx, p in enumerate(lend_people):
        bid = f"B-{idx:05d}"
        borrower_ids.append((bid, p))
        lend_rows.append([bid, p["name"], p["email"], p["segment"], p["region"], p["home"]])
    write_csv(os.path.join(len_dir, "borrowers.csv"),
              ["borrowerId", "name", "email", "segment", "region", "homeCountry"], lend_rows)

    app_rows, loan_rows, coll_rows, delq_rows, rating_rows = [], [], [], [], []
    lidx = 0
    for i in range(cfg["loans"]):
        bid, p = rng.choice(borrower_ids)
        appid = f"APP-{i:06d}"
        req = round(rng.uniform(3000, 400000), 0)
        submitted = REF - timedelta(days=rng.randint(30, 2000))
        status = wchoice(rng, ["Approved", "Declined", "Pending"], [70, 20, 10])
        app_rows.append([appid, bid, req, rng.choice(LOAN_TYPES), status, submitted.strftime("%Y-%m-%d")])
        if status == "Approved":
            lid = f"LN-{lidx:06d}"; lidx += 1
            principal = req
            rate = round(rng.uniform(3.5, 18.5), 2)
            term = rng.choice([24, 36, 48, 60, 84, 120])
            bal = round(principal * rng.uniform(0.2, 1.0), 2)
            dpd = wchoice(rng, [0, 15, 35, 65, 95], [70, 12, 9, 5, 4])
            orig = submitted + timedelta(days=rng.randint(5, 30))
            loan_rows.append([lid, bid, appid, principal, rate, term, bal, dpd, orig.strftime("%Y-%m-%d")])
            if rng.random() < 0.5:
                coll_rows.append([f"COL-{lidx:06d}", lid, rng.choice(["Vehicle", "Property", "Deposit"]),
                                  round(principal * rng.uniform(0.5, 1.4), 2)])
            if dpd >= 30:
                bucket = "30-59" if dpd < 60 else ("60-89" if dpd < 90 else "90+")
                delq_rows.append([f"DQ-{lidx:06d}", lid, bucket,
                                  dt_iso(REF - timedelta(days=rng.randint(1, 60)))])
    write_csv(os.path.join(len_dir, "loan_applications.csv"),
              ["applicationId", "borrowerId", "requestedAmount", "loanType", "status", "submittedDate"], app_rows)
    write_csv(os.path.join(len_dir, "loans.csv"),
              ["loanId", "borrowerId", "applicationId", "principal", "rate", "termMonths", "balance", "dpd", "originationDate"], loan_rows)
    write_csv(os.path.join(len_dir, "collateral.csv"),
              ["collateralId", "loanId", "type", "value"], coll_rows)
    write_csv(os.path.join(len_dir, "delinquency_events.csv"),
              ["eventId", "loanId", "dpdBucket", "flaggedAt"], delq_rows)

    for i, (bid, p) in enumerate(borrower_ids):
        rating_rows.append([f"RR-{i:06d}", bid, rng.choice(GRADES),
                            round(rng.uniform(0.005, 0.35), 4),
                            (REF - timedelta(days=rng.randint(1, 90))).strftime("%Y-%m-%d")])
    write_csv(os.path.join(len_dir, "risk_ratings.csv"),
              ["ratingId", "borrowerId", "grade", "pdScore", "asOfDate"], rating_rows)

    # ---- Ground-truth crosswalk (for validating entity resolution; NOT loaded to prod) ----
    xwalk = []
    lend_by_pid = {}
    for bid, p in borrower_ids:
        lend_by_pid.setdefault(p["pid"], bid)
    for pid, cid in cust_by_pid.items():
        if pid in lend_by_pid:
            xwalk.append([cid, lend_by_pid[pid], people[pid]["email"]])
    write_csv(os.path.join(out, "truth_customer_crosswalk.csv"),
              ["customerId", "borrowerId", "email"], xwalk)

    print(f"\nDone. scale={scale} seed={seed}")
    print(f"  payments customers={len(cust_rows)} accounts={len(acct_rows)} cards={len(card_rows)} "
          f"txns={len(txn_rows)} (fraud={len(fraud_txns)}) alerts={len(alert_rows)}")
    print(f"  lending borrowers={len(lend_rows)} apps={len(app_rows)} loans={len(loan_rows)} "
          f"delinquencies={len(delq_rows)}")
    print(f"  entity-resolution overlap (same person, both systems)={len(xwalk)}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", choices=list(SCALES), default="demo")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "out"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    print(f"Generating Northwind data (scale={a.scale}, seed={a.seed}) -> {a.out}")
    gen(a.scale, a.seed, a.out)
