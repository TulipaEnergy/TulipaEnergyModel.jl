"""Migrate investment-limit columns and asset available-unit bounds."""

from pathlib import Path

import duckdb


ROOT = Path(__file__).resolve().parents[2]


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

    connection = duckdb.connect()
    connection.execute("CREATE TABLE source AS SELECT * FROM read_csv_auto(?)", [str(path)])
    columns = get_columns(connection)
    selections = []

    for column in columns:
        if column in {legacy for legacy, _, _ in limit_columns}:
            _, maximum, _ = next(item for item in limit_columns if item[0] == column)
            if maximum in columns:
                continue
            selections.append(f"{quote_identifier(column)} AS {quote_identifier(maximum)}")
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

    connection = duckdb.connect()
    connection.execute("CREATE TABLE source AS SELECT * FROM read_csv_auto(?)", [str(path)])
    columns = get_columns(connection)
    selections = [quote_identifier(column) for column in columns]

    for column in ("min_available_units", "max_available_units"):
        if column not in columns:
            selections.append(f"NULL::DOUBLE AS {quote_identifier(column)}")

    write_table(connection, path, selections)
    connection.close()
    print(f"{path}: migrated available-unit limits")


def input_folders():
    for folder in sorted((ROOT / "test" / "inputs").iterdir()):
        if folder.is_dir():
            yield folder

    yield ROOT / "benchmark" / "EU"

    for folder in sorted(
        (ROOT / "docs" / "src" / "10-tutorials" / "my-awesome-energy-system").iterdir()
    ):
        if folder.is_dir():
            yield folder


for folder in input_folders():
    migrate_commission(
        folder / "asset-commission.csv",
        (
            ("investment_limit", "investment_max_limit", "investment_min_limit"),
            (
                "investment_limit_storage_energy",
                "investment_max_limit_storage_energy",
                "investment_min_limit_storage_energy",
            ),
        ),
    )
    migrate_commission(
        folder / "flow-commission.csv",
        (("investment_limit", "investment_max_limit", "investment_min_limit"),),
    )
    migrate_asset_milestone(folder / "asset-milestone.csv")
