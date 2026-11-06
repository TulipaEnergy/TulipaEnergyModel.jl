"""Add nullable start-up and shut-down cost columns to asset-milestone CSVs."""

from pathlib import Path

import duckdb

DATA_ROOTS = (
    Path("test/inputs"),
    Path("benchmark/EU"),
    Path("docs/src/10-tutorials/my-awesome-energy-system"),
)
COST_COLUMNS = ("shut_down_cost", "start_up_cost")


def migrate(path: Path) -> None:
    source = path.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect()
    connection.execute(
        f"CREATE TABLE asset_milestone AS SELECT * FROM read_csv_auto('{source}')"
    )
    columns = [
        row[0] for row in connection.execute("DESCRIBE asset_milestone").fetchall()
    ]
    missing_columns = [column for column in COST_COLUMNS if column not in columns]
    if not missing_columns:
        connection.close()
        return

    existing_columns = ", ".join(f'"{column}"' for column in columns)
    new_columns = ", ".join(
        f"CAST(NULL AS DOUBLE) AS {column}" for column in missing_columns
    )
    connection.execute(
        f"COPY (SELECT {existing_columns}, {new_columns} FROM asset_milestone) "
        f"TO '{source}' (HEADER, DELIMITER ',')"
    )
    print(f"{path}: added {', '.join(missing_columns)}")
    connection.close()


for root in DATA_ROOTS:
    if root.exists():
        for path in sorted(root.rglob("asset-milestone.csv")):
            migrate(path)
