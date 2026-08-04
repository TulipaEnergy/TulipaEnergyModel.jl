"""Migrate investment-limit columns and asset available-unit bounds.

Usage examples:
- default repo datasets:
    python utils/scripts/migrate-investment-limits.py
- user folder:
    python utils/scripts/migrate-investment-limits.py --input-folder /path/to/dataset
- specific file(s):
    python utils/scripts/migrate-investment-limits.py --input-file /path/to/asset-commission.csv
- combine user paths with default repo datasets:
    python utils/scripts/migrate-investment-limits.py --input-folder /path/to/dataset --include-default-datasets
"""

import argparse

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

ASSET_COMMISSION_LIMIT_COLUMNS = (
    ("investment_limit", "investment_max_limit", "investment_min_limit"),
    (
        "investment_limit_storage_energy",
        "investment_max_limit_storage_energy",
        "investment_min_limit_storage_energy",
    ),
)
FLOW_COMMISSION_LIMIT_COLUMNS = (
    ("investment_limit", "investment_max_limit", "investment_min_limit"),)


def quote_identifier(identifier):
    return '"' + identifier.replace('"', '""') + '"'


def output_path(path):
    return str(path).replace("'", "''")


def get_columns(connection):
    return [row[0] for row in connection.execute("DESCRIBE source").fetchall()]


def write_table(connection, path, selections):
    connection.execute(
        f"COPY (SELECT {', '.join(selections)} FROM source) "
        f"TO '{output_path(path)}' (HEADER, DELIMITER ',')"
    )


def migrate_commission(path, limit_columns):
    if not path.exists():
        return

    import duckdb

    connection = duckdb.connect()
    connection.execute(
        "CREATE TABLE source AS SELECT * FROM read_csv_auto(?)", [str(path)])
    columns = get_columns(connection)
    selections = []

    for column in columns:
        if column in {legacy for legacy, _, _ in limit_columns}:
            _, maximum, _ = next(
                item for item in limit_columns if item[0] == column)
            if maximum in columns:
                continue
            selections.append(
                f"{quote_identifier(column)} AS {quote_identifier(maximum)}")
            continue

        matching_limit = next(
            (item for item in limit_columns if item[1] == column),
            None,
        )
        if matching_limit is not None and matching_limit[0] in columns:
            selections.append(
                f"COALESCE({quote_identifier(column)}, {quote_identifier(matching_limit[0])}) "
                f"AS {quote_identifier(column)}"
            )
        else:
            selections.append(quote_identifier(column))

    for legacy, maximum, minimum in limit_columns:
        if maximum not in columns and legacy not in columns:
            selections.append(f"NULL::DOUBLE AS {quote_identifier(maximum)}")
        if minimum not in columns:
            selections.append(f"0.0::DOUBLE AS {quote_identifier(minimum)}")

    write_table(connection, path, selections)
    connection.close()
    print(f"{path}: migrated investment limits")


def migrate_asset_milestone(path):
    if not path.exists():
        return

    import duckdb

    connection = duckdb.connect()
    connection.execute(
        "CREATE TABLE source AS SELECT * FROM read_csv_auto(?)", [str(path)])
    columns = get_columns(connection)
    selections = [quote_identifier(column) for column in columns]

    for column in ("min_available_units", "max_available_units"):
        if column not in columns:
            selections.append(f"NULL::DOUBLE AS {quote_identifier(column)}")

    write_table(connection, path, selections)
    connection.close()
    print(f"{path}: migrated available-unit limits")


def default_input_folders():
    for folder in sorted((ROOT / "test" / "inputs").iterdir()):
        if folder.is_dir():
            yield folder

    yield ROOT / "benchmark" / "EU"

    for folder in sorted(
        (ROOT / "docs" / "src" / "10-tutorials" /
         "my-awesome-energy-system").iterdir()
    ):
        if folder.is_dir():
            yield folder


def parse_args():
    parser = argparse.ArgumentParser(
        description="Migrate investment limits and available-unit bounds in CSV datasets."
    )
    parser.add_argument(
        "--input-folder",
        action="append",
        default=[],
        metavar="PATH",
        help=(
            "Path to a dataset folder containing any of: "
            "asset-commission.csv, flow-commission.csv, asset-milestone.csv. "
            "Can be provided multiple times."
        ),
    )
    parser.add_argument(
        "--input-file",
        action="append",
        default=[],
        metavar="PATH",
        help=(
            "Path to a specific CSV file to migrate. Supported filenames are "
            "asset-commission.csv, flow-commission.csv, asset-milestone.csv. "
            "Can be provided multiple times."
        ),
    )
    parser.add_argument(
        "--include-default-datasets",
        action="store_true",
        help="Also migrate the default repository datasets (tests, benchmark, tutorials).",
    )
    return parser.parse_args()


def _migrate_dataset_folder(folder):
    migrate_commission(folder / "asset-commission.csv",
                       ASSET_COMMISSION_LIMIT_COLUMNS)
    migrate_commission(folder / "flow-commission.csv",
                       FLOW_COMMISSION_LIMIT_COLUMNS)
    migrate_asset_milestone(folder / "asset-milestone.csv")


def _migrate_specific_file(path):
    file_name = path.name
    if file_name == "asset-commission.csv":
        migrate_commission(path, ASSET_COMMISSION_LIMIT_COLUMNS)
    elif file_name == "flow-commission.csv":
        migrate_commission(path, FLOW_COMMISSION_LIMIT_COLUMNS)
    elif file_name == "asset-milestone.csv":
        migrate_asset_milestone(path)
    else:
        print(
            f"Skipping unsupported file: {path}. "
            "Expected one of asset-commission.csv, flow-commission.csv, asset-milestone.csv"
        )


def main():
    args = parse_args()

    has_user_inputs = bool(args.input_folder or args.input_file)
    migrate_defaults = args.include_default_datasets or not has_user_inputs

    if migrate_defaults:
        for folder in default_input_folders():
            _migrate_dataset_folder(folder)

    for folder_str in args.input_folder:
        folder = Path(folder_str).expanduser().resolve()
        if not folder.exists():
            print(f"Skipping missing folder: {folder}")
            continue
        if not folder.is_dir():
            print(f"Skipping non-folder path: {folder}")
            continue
        _migrate_dataset_folder(folder)

    for file_str in args.input_file:
        path = Path(file_str).expanduser().resolve()
        if not path.exists():
            print(f"Skipping missing file: {path}")
            continue
        if not path.is_file():
            print(f"Skipping non-file path: {path}")
            continue
        _migrate_specific_file(path)


if __name__ == "__main__":
    main()
