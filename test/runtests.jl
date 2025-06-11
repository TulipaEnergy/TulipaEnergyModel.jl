using CSV: CSV
using DataFrames: DataFrames, DataFrame
using DuckDB: DuckDB, DBInterface
using GLPK: GLPK
using HiGHS: HiGHS
using JuMP: JuMP
using Logging: Logging, with_logger
using MathOptInterface: MathOptInterface
using Test: Test, @test, @testset, @test_throws, @test_logs
using TOML: TOML
using TulipaEnergyModel: TulipaEnergyModel
using TulipaIO: TulipaIO

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")
if !isdir(OUTPUT_FOLDER)
    mkdir(OUTPUT_FOLDER)
end

include("utils.jl")

#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".
=#
for (root, dirs, files) in walkdir(@__DIR__)
    for file in files
        if isnothing(match(r"^test-.*\.jl$", file))
            continue
        end
        title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
        @testset "$title" begin
            include(file)
        end
    end
end

# Other general tests that don't need their own file
@testset "Ensuring benchmark loads" begin
    include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
    @test SUITE !== nothing
end

@testset "Ensuring data can be read and create the internal structures" begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "../benchmark/EU/"))
    TulipaEnergyModel.create_internal_tables!(connection)
end
