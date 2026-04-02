"""Migrate investment_group column from asset.csv to group-asset-membership.csv."""

import os
import duckdb

INPUTS = "test/inputs"


def migrate_folder(folder_path):
    asset_path = os.path.join(folder_path, "asset.csv")
    if not os.path.exists(asset_path):
        return

    con = duckdb.connect()
    con.execute(f"CREATE TABLE asset AS SELECT * FROM read_csv_auto('{asset_path}')")

    cols = [r[0] for r in con.execute("DESCRIBE asset").fetchall()]
    if "investment_group" not in cols:
        con.close()
        return

    label = folder_path

    # Write group-asset-membership.csv if any non-NULL investment_group exists
    has_groups = con.execute("SELECT COUNT(*) FROM asset WHERE investment_group IS NOT NULL").fetchone()[0]
    if has_groups:
        membership_path = os.path.join(folder_path, "group-asset-membership.csv")
        con.execute(f"""
            COPY (
                SELECT investment_group AS group_name, asset, capacity AS coefficient
                FROM asset
                WHERE investment_group IS NOT NULL
            ) TO '{membership_path}' (HEADER, DELIMITER ',')
        """)
        print(f"{label}: wrote {has_groups} rows to group-asset-membership.csv")

    # Rewrite asset.csv without investment_group
    remaining = ", ".join(c for c in cols if c != "investment_group")
    con.execute(f"""
        COPY (SELECT {remaining} FROM asset) TO '{asset_path}' (HEADER, DELIMITER ',')
    """)
    print(f"{label}: removed investment_group from asset.csv")

    con.close()


TUTORIALS = "docs/src/10-tutorials/my-awesome-energy-system"

for folder in sorted(os.listdir(INPUTS)):
    migrate_folder(os.path.join(INPUTS, folder))

migrate_folder("benchmark/EU")

for folder in sorted(os.listdir(TUTORIALS)):
    migrate_folder(os.path.join(TUTORIALS, folder))
