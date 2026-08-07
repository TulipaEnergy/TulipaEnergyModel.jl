"""Migrate initial_storage_level from MWh to p.u.

This is a one-time migration: already-migrated values cannot be distinguished
reliably from legacy MWh values smaller than 1.

Usage examples:
- default repository datasets:
    python utils/scripts/migrate-initial-storage-level.py
- user dataset folder:
    python utils/scripts/migrate-initial-storage-level.py --input-folder /path/to/dataset
- user folders plus repository datasets:
    python utils/scripts/migrate-initial-storage-level.py --input-folder /path/to/dataset --include-default-datasets
"""

import argparse
from pathlib import Path

import duckdb


ROOT = Path(__file__).resolve().parents[2]
OBZ_DATA = ROOT / "docs" / "src" / "data" / "obz"


def output_path(path):
    return str(path).replace("'", "''")


def columns(connection, table):
    return {row[0] for row in connection.execute(f"DESCRIBE {table}").fetchall()}


def migrate_dataset(folder):
    milestone_path = folder / "asset-milestone.csv"
    asset_path = folder / "asset.csv"
    both_path = folder / "asset-both.csv"
    if not milestone_path.exists():
        return
    if not asset_path.exists() or not both_path.exists():
        raise ValueError(
            f"{folder}: asset.csv and asset-both.csv are required to migrate "
            "asset-milestone.csv"
        )

    connection = duckdb.connect()
    connection.execute(
        "CREATE TABLE asset_milestone AS "
        "SELECT ROW_NUMBER() OVER () AS migration_row_id, * FROM read_csv_auto(?)",
        [str(milestone_path)],
    )
    connection.execute(
        "CREATE TABLE asset AS SELECT * FROM read_csv_auto(?)", [str(asset_path)]
    )
    connection.execute(
        "CREATE TABLE asset_both AS SELECT * FROM read_csv_auto(?)", [str(both_path)]
    )

    milestone_columns = columns(connection, "asset_milestone")
    if "initial_storage_level" not in milestone_columns:
        connection.close()
        return
    has_values = connection.execute(
        "SELECT COUNT(*) FROM asset_milestone "
        "WHERE initial_storage_level IS NOT NULL AND initial_storage_level != 0"
    ).fetchone()[0]
    if not has_values:
        connection.close()
        return

    required = {
        "asset_milestone": {"asset", "milestone_year", "initial_storage_level", "investable"},
        "asset": {"asset", "capacity_storage_energy", "storage_method_energy"},
        "asset_both": {
            "asset",
            "milestone_year",
            "initial_storage_units",
            "decommissionable",
        },
    }
    for table, expected in required.items():
        missing = expected - columns(connection, table)
        if missing:
            raise ValueError(f"{folder}: {table} is missing columns {sorted(missing)}")

    connection.execute(
        """
        CREATE TABLE migration_data AS
        SELECT
            asset_milestone.asset,
            asset_milestone.milestone_year,
            asset_milestone.initial_storage_level,
            ANY_VALUE(asset.capacity_storage_energy) *
                SUM(asset_both.initial_storage_units) AS initial_energy_capacity,
            ANY_VALUE(asset.storage_method_energy) != 'none'
                AND (
                    BOOL_OR(asset_milestone.investable)
                    OR BOOL_OR(asset_both.decommissionable)
                ) AS decision_dependent
        FROM asset_milestone
        LEFT JOIN asset USING (asset)
        LEFT JOIN asset_both
            ON asset_milestone.asset = asset_both.asset
            AND asset_milestone.milestone_year = asset_both.milestone_year
        WHERE asset_milestone.initial_storage_level IS NOT NULL
            AND asset_milestone.initial_storage_level != 0
        GROUP BY
            asset_milestone.asset,
            asset_milestone.milestone_year,
            asset_milestone.initial_storage_level
        """
    )

    errors = []
    for row in connection.execute(
        """
        SELECT *
        FROM migration_data
        WHERE
            NOT isfinite(initial_storage_level)
            OR initial_storage_level < 0
            OR initial_energy_capacity IS NULL
            OR initial_energy_capacity <= 0
            OR decision_dependent
            OR initial_storage_level / initial_energy_capacity > 1
        ORDER BY asset, milestone_year
        """
    ).fetchall():
        asset, year, level, capacity, decision_dependent = row
        if decision_dependent:
            reason = "available capacity depends on investment or decommission decisions"
        elif capacity is None or capacity <= 0:
            reason = f"initial energy capacity is {capacity}"
        elif not 0 <= level <= capacity:
            reason = f"legacy level {level} MWh is outside [0, {capacity}] MWh"
        else:
            reason = f"legacy level {level} is not finite"
        errors.append(f"{asset} ({year}): {reason}")

    if errors:
        connection.close()
        raise ValueError(
            f"{folder}: cannot preserve legacy results:\n- " + "\n- ".join(errors)
        )

    migrated_count = connection.execute("SELECT COUNT(*) FROM migration_data").fetchone()[0]
    if migrated_count:
        connection.execute(
            f"""
            COPY (
                SELECT * EXCLUDE (migration_row_id)
                FROM (
                    SELECT asset_milestone.* REPLACE (
                        CASE
                            WHEN asset_milestone.initial_storage_level IS NULL
                                OR asset_milestone.initial_storage_level = 0
                            THEN asset_milestone.initial_storage_level
                            ELSE asset_milestone.initial_storage_level /
                                migration_data.initial_energy_capacity
                        END AS initial_storage_level
                    )
                    FROM asset_milestone
                    LEFT JOIN migration_data USING (asset, milestone_year)
                )
                ORDER BY migration_row_id
            ) TO '{output_path(milestone_path)}' (HEADER, DELIMITER ',')
            """
        )
        print(f"{folder}: migrated {migrated_count} initial storage levels")
    connection.close()


def migrate_obz_data():
    basic_path = OBZ_DATA / "assets-storage-basic-data.csv"
    yearly_path = OBZ_DATA / "assets-storage-yearly-data.csv"
    connection = duckdb.connect()
    connection.execute(
        "CREATE TABLE basic AS SELECT * FROM read_csv_auto(?)", [str(basic_path)]
    )
    connection.execute(
        "CREATE TABLE yearly AS "
        "SELECT ROW_NUMBER() OVER () AS migration_row_id, * FROM read_csv_auto(?)",
        [str(yearly_path)],
    )
    invalid = connection.execute(
        """
        SELECT yearly.name, yearly.milestone_year
        FROM yearly
        LEFT JOIN basic USING (name)
        WHERE yearly.initial_storage_level IS NOT NULL
            AND yearly.initial_storage_level != 0
            AND (
                basic.capacity_storage_energy IS NULL
                OR basic.capacity_storage_energy <= 0
                OR yearly.initial_storage_units <= 0
                OR yearly.initial_storage_level < 0
                OR yearly.initial_storage_level /
                    (basic.capacity_storage_energy * yearly.initial_storage_units) > 1
            )
        """
    ).fetchall()
    if invalid:
        connection.close()
        raise ValueError(f"{OBZ_DATA}: cannot migrate rows {invalid}")

    connection.execute(
        f"""
        COPY (
            SELECT * EXCLUDE (migration_row_id)
            FROM (
                SELECT yearly.* REPLACE (
                    CASE
                        WHEN yearly.initial_storage_level IS NULL
                            OR yearly.initial_storage_level = 0
                        THEN yearly.initial_storage_level
                        ELSE yearly.initial_storage_level /
                            (basic.capacity_storage_energy * yearly.initial_storage_units)
                    END AS initial_storage_level
                )
                FROM yearly
                LEFT JOIN basic USING (name)
            )
            ORDER BY migration_row_id
        ) TO '{output_path(yearly_path)}' (HEADER, DELIMITER ',')
        """
    )
    migrated_count = connection.execute(
        "SELECT COUNT(*) FROM yearly WHERE initial_storage_level IS NOT NULL AND initial_storage_level != 0"
    ).fetchone()[0]
    connection.close()
    print(f"{OBZ_DATA}: migrated {migrated_count} initial storage levels")


def default_input_folders():
    yield from sorted(folder for folder in (ROOT / "test" / "inputs").iterdir() if folder.is_dir())
    yield ROOT / "benchmark" / "EU"
    tutorials = ROOT / "docs" / "src" / "10-tutorials" / "my-awesome-energy-system"
    yield from sorted(folder for folder in tutorials.iterdir() if folder.is_dir())


def parse_args():
    parser = argparse.ArgumentParser(
        description="Migrate initial_storage_level from MWh to p.u."
    )
    parser.add_argument(
        "--input-folder",
        action="append",
        default=[],
        metavar="PATH",
        help="Dataset folder containing asset.csv, asset-both.csv, and asset-milestone.csv.",
    )
    parser.add_argument(
        "--include-default-datasets",
        action="store_true",
        help="Also migrate the repository test, benchmark, tutorial, and OBZ datasets.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    migrate_defaults = args.include_default_datasets or not args.input_folder

    if migrate_defaults:
        for folder in default_input_folders():
            migrate_dataset(folder)
        migrate_obz_data()

    for folder_string in args.input_folder:
        folder = Path(folder_string).expanduser().resolve()
        if not folder.is_dir():
            raise ValueError(f"Not a dataset folder: {folder}")
        migrate_dataset(folder)


if __name__ == "__main__":
    main()
