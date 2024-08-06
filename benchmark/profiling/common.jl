# This file should be common for all benchmark scripts
using BenchmarkTools, DuckDB, TulipaIO, TulipaEnergyModel

norse_dir = joinpath(@__DIR__, "..", "..", "test", "inputs", "Norse")
eu_dir = joinpath(@__DIR__, "..", "EU")
dir = norse_dir

function _read_dir_and_return_connection(dir)
    con = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(con, dir)

    return con
end
