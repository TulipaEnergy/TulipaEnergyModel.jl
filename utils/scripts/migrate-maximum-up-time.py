"""Add a nullable maximum_up_time column to asset CSVs."""

from pathlib import Path

import duckdb

DATA_ROOTS = (
    Path("test/inputs"),
    Path("benchmark/EU"),
    Path("docs/src/10-tutorials/my-awesome-energy-system"),
)
NEW_COLUMN = "maximum_up_time"


def migrate(path: Path) -> None:
    source = path.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect()
    # Read every value as text so the existing values are written back unchanged.
    connection.execute(
        f"CREATE TABLE asset AS SELECT * FROM read_csv('{source}', header = true, all_varchar = true)"
    )
    columns = [row[0] for row in connection.execute("DESCRIBE asset").fetchall()]
    if NEW_COLUMN in columns:
        connection.close()
        return

    existing_columns = ", ".join(f'"{column}"' for column in columns)
    connection.execute(
        f"COPY (SELECT {existing_columns}, CAST(NULL AS INTEGER) AS {NEW_COLUMN} FROM asset) "
        f"TO '{source}' (HEADER, DELIMITER ',')"
    )
    print(f"{path}: added {NEW_COLUMN}")
    connection.close()


for root in DATA_ROOTS:
    if root.exists():
        for path in sorted(root.rglob("asset.csv")):
            migrate(path)
