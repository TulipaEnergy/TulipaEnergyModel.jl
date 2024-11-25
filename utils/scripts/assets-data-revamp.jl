using DataFrames, DuckDB, TulipaIO, TulipaEnergyModel

include("../csv-modifications.jl")

# Local cleanup to ensure clean files
apply_to_files_named(rm, "asset.csv")
apply_to_files_named(rm, "asset-milestone.csv")
apply_to_files_named(rm, "asset-commission.csv")
apply_to_files_named(rm, "asset-both.csv")
apply_to_files_named(rm, "flow.csv")
apply_to_files_named(rm, "flow-milestone.csv")
apply_to_files_named(rm, "flow-commission.csv")
apply_to_files_named(rm, "flow-both.csv")
run(`git restore test/inputs/ benchmark/EU/`)

# FIXME: Definition of decommissionable?

#=
    TABLE asset <- graph-assets-data

    name -> asset
    type
    group
    capacity
    min_operating_point -> ANY FROM assets_data
    investment_method
    technical_lifetime
    economic_lifetime
    discount_rate
    consumer_balance_sense -> ANY FROM assets_data
    capacity_storage_energy
    is_seasonal -> ANY FROM assets_data
    use_binary_storage_method -> ANY FROM assets_data
    unit_commitment -> ANY FROM assets_data
    unit_commitment_method -> ANY FROM assets_data
    unit_commitment_integer -> ANY FROM assets_data
    ramping -> ANY FROM assets_data
=#
apply_to_files_named("asset.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv =
            DuckDB.query(
                con,
                "SELECT
                    gad.name as asset,
                    ANY_VALUE(type) AS type,
                    ANY_VALUE(gad.group) AS group,
                    ANY_VALUE(gad.capacity) AS capacity,
                    ANY_VALUE(ad.min_operating_point) AS min_operating_point,
                    ANY_VALUE(investment_method) AS investment_method,
                    ANY_VALUE(investment_integer) AS investment_integer,
                    ANY_VALUE(technical_lifetime) AS technical_lifetime,
                    ANY_VALUE(economic_lifetime) AS economic_lifetime,
                    ANY_VALUE(discount_rate) AS discount_rate,
                    ANY_VALUE(consumer_balance_sense) AS consumer_balance_sense,
                    ANY_VALUE(capacity_storage_energy) AS capacity_storage_energy,
                    ANY_VALUE(is_seasonal) AS is_seasonal,
                    ANY_VALUE(use_binary_storage_method) AS use_binary_storage_method,
                    ANY_VALUE(unit_commitment) AS unit_commitment,
                    ANY_VALUE(unit_commitment_method) AS unit_commitment_method,
                    ANY_VALUE(unit_commitment_integer) AS unit_commitment_integer,
                    ANY_VALUE(ramping) AS ramping,
                    ANY_VALUE(storage_method_energy) AS storage_method_energy,
                    ANY_VALUE(energy_to_power_ratio) AS energy_to_power_ratio,
                    ANY_VALUE(investment_integer_storage_energy) AS investment_integer_storage_energy,
                    ANY_VALUE(max_ramp_up) AS max_ramp_up,
                    ANY_VALUE(max_ramp_down) AS max_ramp_down,
                FROM graph_assets_data AS gad
                LEFT JOIN assets_data AS ad
                    ON gad.name = ad.name
                GROUP BY asset
                ORDER BY asset
                ",
            ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE flow = graph-flows-data
=#
apply_to_files_named("flow.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv =
            DuckDB.query(
                con,
                "SELECT
                    gfd.from_asset,
                    gfd.to_asset,
                    ANY_VALUE(carrier) AS carrier,
                    ANY_VALUE(is_transport) AS is_transport,
                    ANY_VALUE(capacity) AS capacity,
                    ANY_VALUE(technical_lifetime) AS technical_lifetime,
                    ANY_VALUE(economic_lifetime) AS economic_lifetime,
                    ANY_VALUE(discount_rate) AS discount_rate,
                    ANY_VALUE(investment_integer) AS investment_integer,
                FROM graph_flows_data AS gfd
                LEFT JOIN flows_data AS fd
                    ON gfd.from_asset = fd.from_asset
                    AND gfd.to_asset = fd.to_asset
                GROUP BY gfd.from_asset, gfd.to_asset
                ",
            ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE asset-milestone

    asset -> ?
    milestone_year -> ?
    peak_demand -> assets_data WHERE year=commission_year
    storage_inflows -> assets_data WHERE year=commission_year
    initial_storage_level -> assets_data WHERE year=commission_year
    max_energy_timeframe_partition  -> assets_data WHERE year=commission_year
    min_energy_timeframe_partition -> assets_data WHERE year=commission_year
    max_ramp_up -> assets_data WHERE year=commission_year
    max_ramp_down -> assets_data WHERE year=commission_year
=#
apply_to_files_named("asset-milestone.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv =
            DuckDB.query(
                con,
                "SELECT
                    name as asset,
                    year as milestone_year,
                    ANY_VALUE(investable) AS investable,
                    ANY_VALUE(peak_demand) AS peak_demand,
                    ANY_VALUE(storage_inflows) AS storage_inflows,
                    ANY_VALUE(initial_storage_level) AS initial_storage_level,
                    ANY_VALUE(min_energy_timeframe_partition) AS min_energy_timeframe_partition,
                    ANY_VALUE(max_energy_timeframe_partition) AS max_energy_timeframe_partition,
                FROM assets_data AS ad
                GROUP BY asset, milestone_year
                ",
            ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE flow-milestone

    from_asset
    to_asset
    milestone_year
    variable_cost
    efficiency
=#
apply_to_files_named("flow-milestone.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv = DuckDB.query(
            con,
            "SELECT
                from_asset,
                to_asset,
                year AS milestone_year,
                ANY_VALUE(investable) AS investable,
            FROM flows_data AS fd
            GROUP BY from_asset, to_asset, milestone_year
            ",
        ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE asset-commission <- vintage-assets-data

    keep:
    name -> asset
    commission_year
    fixed_cost
    investment_cost
    fixed_cost_storage_energy
    investment_cost_storage_energy
    storage_method_energy -> assets_data WHERE year=commission_year
    energy_to_power_ratio -> assets_data WHERE year=commission_year
=#
apply_to_files_named("asset-commission.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv =
            DuckDB.query(
                con,
                "SELECT
                    vad.name as asset,
                    vad.commission_year,
                    ANY_VALUE(fixed_cost) AS fixed_cost,
                    ANY_VALUE(investment_cost) AS investment_cost,
                    ANY_VALUE(investment_limit) AS investment_limit,
                    ANY_VALUE(vad.fixed_cost_storage_energy) AS fixed_cost_storage_energy,
                    ANY_VALUE(vad.investment_cost_storage_energy) AS investment_cost_storage_energy,
                    ANY_VALUE(investment_limit_storage_energy) AS investment_limit_storage_energy,
                FROM vintage_assets_data AS vad
                LEFT JOIN assets_data AS ad
                    ON vad.name = ad.name
                    AND vad.commission_year = ad.commission_year
                GROUP BY vad.name, vad.commission_year
                ",
            ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE flow-commission

    from_asset
    to_asset
    commission_year
    fixed_cost
    investment_cost
=#
apply_to_files_named("flow-commission.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv =
            DuckDB.query(
                con,
                "SELECT
                    vfd.from_asset,
                    vfd.to_asset,
                    vfd.commission_year,
                    ANY_VALUE(fixed_cost) AS fixed_cost,
                    ANY_VALUE(investment_cost) AS investment_cost,
                    ANY_VALUE(efficiency) AS efficiency,
                    ANY_VALUE(investment_limit) AS investment_limit,
                FROM vintage_flows_data AS vfd
                LEFT JOIN flows_data AS fd
                    ON vfd.from_asset = fd.from_asset
                    AND vfd.to_asset = fd.to_asset
                GROUP BY vfd.from_asset, vfd.to_asset, vfd.commission_year
                ",
            ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE asset-both <- assets-data

    keep:
    name -> asset
    year -> milestone_year
    commission_year
    active
    investable
    decommissionable -> ?
    investment_integer
    investment_limit
    initial_units
    investment_integer_storage_energy
    investment_limit_storage_energy
    initial_storage_units
=#
apply_to_files_named("asset-both.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv = DuckDB.query(
            con,
            "SELECT
                name as asset,
                year as milestone_year,
                commission_year,
                active,
                NOT investable AS decommissionable,
                initial_units,
                initial_storage_units,
                units_on_cost,
            FROM assets_data AS ad
            ",
        ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

#=
    TABLE flow-both

    from_asset
    to_asset
    milestone_year
    commission_year
    active
    investable
    decommissionable
    investment_integer
    investment_limit
    initial_export_units
    initial_import_units
=#
apply_to_files_named("flow-both.csv"; include_missing = true) do path
    touch(path)
    change_file(path) do tcsv
        dirpath = dirname(path)
        con = DBInterface.connect(DuckDB.DB)
        schemas = TulipaEnergyModel.schema_per_table_name
        read_csv_folder(con, dirpath; schemas)

        tcsv.csv = DuckDB.query(
            con,
            "SELECT
                from_asset,
                to_asset,
                year AS milestone_year,
                commission_year,
                active,
                NOT investable AS decommissionable,
                variable_cost,
                initial_export_units,
                initial_import_units,
            FROM flows_data AS fd
            ",
        ) |> DataFrame

        tcsv.units = ["" for _ in 1:size(tcsv.csv, 2)]
    end
end

# Remove old files
for a_or_f in ("assets", "flows"),
    filename in ("$a_or_f-data.csv", "graph-$a_or_f-data.csv", "vintage-$a_or_f-data.csv")

    apply_to_files_named(rm, filename)
end
