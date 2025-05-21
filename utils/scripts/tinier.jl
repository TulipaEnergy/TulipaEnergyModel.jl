# Creates a tinier set based on Tiny
using DuckDB

root_dir = joinpath(@__DIR__, "..", "..")
test_inputs = joinpath(root_dir, "test", "inputs")
tiny_dir = joinpath(test_inputs, "Tiny")
tinier_dir = joinpath(test_inputs, "Tinier")
if isdir(tinier_dir)
    rm(tinier_dir; force = true, recursive = true)
end
mkdir(tinier_dir)

for (filename, cols) in (
    ("asset-both", ["asset", "milestone_year", "commission_year", "initial_units"]),
    (
        "asset-commission",
        [
            "asset",
            "commission_year",
            "investment_cost",
            "investment_limit",
            "fixed_cost_storage_energy",
        ],
    ),
    ("asset-milestone", ["asset", "milestone_year", "investable", "peak_demand"]),
    (
        "asset",
        [
            "asset",
            "type",
            "capacity",
            "investment_method",
            "investment_integer",
            "technical_lifetime",
            "discount_rate",
        ],
    ),
    ("assets-profiles", ["all"]),
    (
        "flow-both",
        ["from_asset", "to_asset", "milestone_year", "commission_year", "decommissionable"],
    ),
    ("flow-commission", ["from_asset", "to_asset", "commission_year"]),
    ("flow-milestone", ["from_asset", "to_asset", "milestone_year", "variable_cost"]),
    ("flow", ["from_asset", "to_asset", "technical_lifetime", "discount_rate"]),
    ("profiles-rep-periods", ["all"]),
    ("rep-periods-data", ["all"]),
    ("rep-periods-mapping", ["all"]),
    ("timeframe-data", ["all"]),
    ("year-data", ["all"]),
)
    tiny_filepath = joinpath(tiny_dir, "$filename.csv")
    tinier_filepath = joinpath(tinier_dir, "$filename.csv")

    if cols == ["all"]
        @info "Copying '$filename'"
        cp(tiny_filepath, tinier_filepath)
        continue
    end

    connection = DBInterface.connect(DuckDB.DB)
    _q(s) = DuckDB.query(connection, s)

    select_str = join(cols, ", ")
    _q("CREATE TABLE t AS SELECT $select_str FROM read_csv('$tiny_filepath')")

    @info "Simplifying '$filename' "
    _q("COPY t TO '$tinier_filepath' (HEADER, DELIMITER ',')")
end
