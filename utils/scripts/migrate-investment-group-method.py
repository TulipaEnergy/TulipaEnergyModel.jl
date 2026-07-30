"""Migrate boolean invest_method values to investment-group methods."""

import os

import duckdb


INPUTS = "test/inputs"
BENCHMARK = "benchmark/EU"
TUTORIALS = "docs/src/10-tutorials/my-awesome-energy-system"


def migrate_folder(folder_path):
    path = os.path.join(folder_path, "investment-group-asset.csv")
    if not os.path.exists(path):
        return

    con = duckdb.connect()
    con.execute(f"CREATE TABLE investment_group_asset AS SELECT * FROM read_csv_auto('{path}')")

    columns = [row[0] for row in con.execute("DESCRIBE investment_group_asset").fetchall()]
    if "invest_method" not in columns:
        con.close()
        return

    legacy_count = con.execute(
        """
        SELECT COUNT(*)
        FROM investment_group_asset
        WHERE lower(CAST(invest_method AS VARCHAR)) IN ('true', 'false')
        """
    ).fetchone()[0]
    if legacy_count == 0:
        con.close()
        return

    con.execute(
        f"""
        COPY (
            SELECT * REPLACE (
                CASE lower(CAST(invest_method AS VARCHAR))
                    WHEN 'true' THEN 'use_only_investment_units'
                    WHEN 'false' THEN 'none'
                    ELSE CAST(invest_method AS VARCHAR)
                END AS invest_method
            )
            FROM investment_group_asset
        ) TO '{path}' (HEADER, DELIMITER ',')
        """
    )
    print(f"{folder_path}: migrated {legacy_count} invest_method values")
    con.close()


for folder in sorted(os.listdir(INPUTS)):
    migrate_folder(os.path.join(INPUTS, folder))

migrate_folder(BENCHMARK)

for folder in sorted(os.listdir(TUTORIALS)):
    migrate_folder(os.path.join(TUTORIALS, folder))
