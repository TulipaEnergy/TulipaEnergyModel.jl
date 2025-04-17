# file with auxiliary functions for the testing
include("data-simplest.jl")

function _read_csv_folder(connection, input_dir)
    schemas = TulipaEnergyModel.schema_per_table_name
    TulipaIO.read_csv_folder(connection, input_dir; schemas, table_name_prefix = "input_")

    for table_name in
        ("rep_periods_data", "rep_periods_mapping", "timeframe_data", "profiles_rep_periods")
        DuckDB.query(connection, "ALTER TABLE input_$table_name RENAME TO cluster_$table_name")
    end

    return nothing
end

function _tiny_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Tiny"))
    return connection
end

function _storage_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Storage"))
    return connection
end
