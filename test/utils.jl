# file with auxiliary functions for the testing
include("data-simplest.jl")

function _read_csv_folder(connection, input_dir)
    schemas = TulipaEnergyModel.schema_per_table_name
    return TulipaIO.read_csv_folder(connection, input_dir; schemas)
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

function _test_rows_exist(rows_to_test::Vector, table_to_test::DataFrame)
    return [
        any(
            row ->
                row.asset == asset &&
                    row.year == year &&
                    row.rep_period == rep_period &&
                    row.time_block_start == time_block_start &&
                    row.time_block_end == time_block_end,
            eachrow(table_to_test),
        ) for (asset, year, rep_period, time_block_start, time_block_end) in rows_to_test
    ]
end
