using CSV
using Cbc
using DataFrames
using DuckDB
using GLPK
using Graphs
using HiGHS
using JuMP
using MathOptInterface
using Test
using TOML
using TulipaEnergyModel
using TulipaIO

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")
if !isdir(OUTPUT_FOLDER)
    mkdir(OUTPUT_FOLDER)
end

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
    create_internal_structures(connection)
end
