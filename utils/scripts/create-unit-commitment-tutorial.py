"""Create the small hourly dataset used by the unit-commitment tutorial."""

import csv
import shutil
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/src/10-tutorials/my-awesome-energy-system/tutorial-1"
TARGET = ROOT / "docs/src/10-tutorials/my-awesome-energy-system/tutorial-uc"
PROFILE_FILE = TARGET / "profiles-rep-periods.csv"

TARGET.parent.mkdir(parents=True, exist_ok=True)
if TARGET.exists():
    shutil.rmtree(TARGET)
shutil.copytree(SOURCE, TARGET)

connection = duckdb.connect()
week = connection.execute(
    """
    WITH profiles AS (
        SELECT
            timestep,
            MAX(value) FILTER (WHERE profile_name = 'demand-demand') AS demand,
            MAX(value) FILTER (WHERE profile_name = 'availability-wind') AS wind,
            MAX(value) FILTER (WHERE profile_name = 'availability-solar') AS solar
        FROM read_csv_auto(?)
        GROUP BY timestep
    ),
    weekly AS (
        SELECT
            ((timestep - 1) // 168) AS week,
            MIN(timestep) AS first_timestep,
            MAX(timestep) AS last_timestep,
            MAX(demand * 1000 - wind * 400 - solar * 500)
                - MIN(demand * 1000 - wind * 400 - solar * 500) AS net_load_range
        FROM profiles
        GROUP BY week
        ORDER BY net_load_range DESC
        LIMIT 1
    )
    SELECT first_timestep, last_timestep
    FROM weekly
    """,
    [str(SOURCE / "profiles-rep-periods.csv")],
).fetchone()

profile_rows = connection.execute(
    """
    SELECT profile_name, milestone_year, rep_period,
           timestep - ? + 1 AS timestep, value
    FROM read_csv_auto(?)
    WHERE timestep BETWEEN ? AND ?
    ORDER BY profile_name, timestep
    """,
    [week[0], str(SOURCE / "profiles-rep-periods.csv"), week[0], week[1]],
).fetchall()

with PROFILE_FILE.open("w", newline="") as file:
    writer = csv.writer(file)
    writer.writerow(
        ["profile_name", "milestone_year", "rep_period", "timestep", "value"]
    )
    writer.writerows(profile_rows)

for filename in ("rep-periods-data.csv", "timeframe-data.csv"):
    path = TARGET / filename
    rows = list(csv.DictReader(path.open(newline="")))
    for row in rows:
        row["num_timesteps"] = "168"
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

path = TARGET / "asset.csv"
rows = list(csv.DictReader(path.open(newline="")))
fields = list(rows[0].keys())
for field in ("min_operating_point", "unit_commitment", "unit_commitment_integer"):
    fields.append(field)
for row in rows:
    row["min_operating_point"] = "0.0"
    row["unit_commitment"] = "none"
    row["unit_commitment_integer"] = "false"
    if row["asset"] == "ccgt":
        row["capacity"] = "200.0"
        row["min_operating_point"] = "0.4"
        row["unit_commitment"] = "3var"
        row["unit_commitment_integer"] = "true"
        row["minimum_up_time"] = "6"
        row["minimum_down_time"] = "4"
    elif row["asset"] == "ocgt":
        row["capacity"] = "50.0"
        row["min_operating_point"] = "0.2"
        row["unit_commitment"] = "3var"
        row["unit_commitment_integer"] = "true"
with path.open("w", newline="") as file:
    writer = csv.DictWriter(file, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

path = TARGET / "asset-both.csv"
rows = list(csv.DictReader(path.open(newline="")))
for row in rows:
    row["initial_units"] = (
        "4.0"
        if row["asset"] == "ccgt"
        else "2.0"
        if row["asset"] == "ocgt"
        else row["initial_units"]
    )
with path.open("w", newline="") as file:
    writer = csv.DictWriter(file, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

path = TARGET / "asset-milestone.csv"
rows = list(csv.DictReader(path.open(newline="")))
fields = list(rows[0].keys()) + ["units_on_cost"]
for row in rows:
    row["units_on_cost"] = "0.0"
    if row["asset"] == "ccgt":
        row["units_on_cost"] = "2000.0"
    elif row["asset"] == "ocgt":
        row["units_on_cost"] = "300.0"
with path.open("w", newline="") as file:
    writer = csv.DictWriter(file, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

print(f"Created {TARGET} using timesteps {week[0]}:{week[1]}")
