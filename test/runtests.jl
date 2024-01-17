using CSV
using Cbc
using DataFrames
using GLPK
using Graphs
using HiGHS
using JuMP
using MathOptInterface
using Test
using TulipaEnergyModel

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

# Run all files in test folder starting with `test-` and ending with `.jl`
test_files = filter(file -> startswith("test-")(file) && endswith(".jl")(file), readdir(@__DIR__))
for file in test_files
    include(file)
end

# Other general tests that don't need their own file
@testset "Ensuring benchmark loads" begin
    include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
    @test SUITE !== nothing
end

@testset "Ensuring EU data can be read" begin
    create_graph_and_representative_periods_from_csv_folder(joinpath(@__DIR__, "../benchmark/EU/"))
end
