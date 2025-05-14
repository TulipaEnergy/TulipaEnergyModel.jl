# file with auxiliary functions for the testing
include("data-simplest.jl")

function _read_csv_folder(connection, instance_dir)
    # This expected the folders `input` and `cluster` inside `instance_dir`
    TulipaIO.read_csv_folder(
        connection,
        joinpath(instance_dir, "input");
        database_schema = "input",
        schemas = TulipaEnergyModel.sql_input_schema_per_table_name,
    )
    TulipaIO.read_csv_folder(
        connection,
        joinpath(instance_dir, "cluster");
        database_schema = "cluster",
        schemas = TulipaEnergyModel.sql_cluster_schema_per_table_name,
    )

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
