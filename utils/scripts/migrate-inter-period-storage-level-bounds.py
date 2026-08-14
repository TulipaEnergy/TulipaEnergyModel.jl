"""Add the inter-period storage-level bound formulation to maintained asset tables."""

import os

import duckdb


INPUTS = "test/inputs"
TUTORIALS = "docs/src/10-tutorials/my-awesome-energy-system"
COLUMN = "inter_period_storage_level_bounds"
DEFAULT = "inter_period_only"


def migrate_folder(folder_path):
    asset_path = os.path.join(folder_path, "asset.csv")
    if not os.path.exists(asset_path):
        return

    con = duckdb.connect()
    con.execute(f"CREATE TABLE asset_data AS SELECT * FROM read_csv_auto('{asset_path}')")
    columns = [row[0] for row in con.execute("DESCRIBE asset_data").fetchall()]
    if COLUMN in columns:
        con.close()
        return

    con.execute(f"ALTER TABLE asset_data ADD COLUMN {COLUMN} VARCHAR DEFAULT '{DEFAULT}'")
    con.execute(f"COPY asset_data TO '{asset_path}' (HEADER, DELIMITER ',')")
    print(f"{folder_path}: added {COLUMN}={DEFAULT}")
    con.close()


for folder in sorted(os.listdir(INPUTS)):
    migrate_folder(os.path.join(INPUTS, folder))

migrate_folder("benchmark/EU")

for folder in sorted(os.listdir(TUTORIALS)):
    migrate_folder(os.path.join(TUTORIALS, folder))
