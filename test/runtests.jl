using CSV
using DataFrames
using Graphs
using JuMP
using TulipaEnergyModel
using Test

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

# Run all files in test folder starting with `test-`
for file in readdir(@__DIR__)
    if !startswith("test-")(file)
        continue
    end
    include(file)
end

# Other general tests that don't need their own file
@testset "Ensuring benchmark loads" begin
    include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
    @test SUITE !== nothing
end
