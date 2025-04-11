# file with auxiliary functions for the testing
include("data-simplest.jl")

function _read_csv_folder(connection, input_dir)
    TulipaIO.read_csv_folder(
        connection,
        input_dir;
        database_schema = "input",
        schemas = TulipaEnergyModel.sql_input_schema_per_table_name,
    )

    for table_name in
        ("rep_periods_data", "rep_periods_mapping", "timeframe_data", "profiles_rep_periods")
        DuckDB.query(connection, "CREATE SCHEMA IF NOT EXISTS cluster")
        DuckDB.query(connection, "CREATE TABLE cluster.$table_name AS FROM input.$table_name")
    end

    return nothing
end

function _register_df(connection, df, schema_name, table_name)
    DuckDB.register_data_frame(connection, df, "t_$table_name")
    DuckDB.execute(connection, "CREATE SCHEMA IF NOT EXISTS $schema_name")
    DuckDB.execute(connection, "CREATE TABLE $schema_name.$table_name AS FROM t_$table_name")
    DuckDB.execute(connection, "DROP VIEW t_$table_name")
    return
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
