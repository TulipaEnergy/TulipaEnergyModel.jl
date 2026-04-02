"""Migrate min/max_investment_limit columns in group-asset.csv to constraint_sense + rhs rows."""

import os
import duckdb

INPUTS = "test/inputs"
TUTORIALS = "docs/src/10-tutorials/my-awesome-energy-system"


def migrate_folder(folder_path):
    path = os.path.join(folder_path, "group-asset.csv")
    if not os.path.exists(path):
        return

    con = duckdb.connect()
    con.execute(f"CREATE TABLE ga AS SELECT * FROM read_csv_auto('{path}')")

    cols = [r[0] for r in con.execute("DESCRIBE ga").fetchall()]
    if "min_investment_limit" not in cols and "max_investment_limit" not in cols:
        con.close()
        return

    label = folder_path

    # Build other columns (everything except the two limit columns)
    other = ", ".join(c for c in cols if c not in ("min_investment_limit", "max_investment_limit"))

    con.execute(f"""
        CREATE TABLE ga_new AS
        SELECT {other}, '>=' AS constraint_sense, min_investment_limit AS rhs
        FROM ga WHERE min_investment_limit IS NOT NULL
        UNION ALL
        SELECT {other}, '<=' AS constraint_sense, max_investment_limit AS rhs
        FROM ga WHERE max_investment_limit IS NOT NULL
        ORDER BY name, milestone_year, constraint_sense
    """)

    con.execute(f"COPY ga_new TO '{path}' (HEADER, DELIMITER ',')")
    n = con.execute("SELECT COUNT(*) FROM ga_new").fetchone()[0]
    print(f"{label}: wrote {n} rows to group-asset.csv")

    con.close()


for folder in sorted(os.listdir(INPUTS)):
    migrate_folder(os.path.join(INPUTS, folder))

migrate_folder("benchmark/EU")

for folder in sorted(os.listdir(TUTORIALS)):
    migrate_folder(os.path.join(TUTORIALS, folder))
