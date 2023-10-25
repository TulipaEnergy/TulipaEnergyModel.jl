using CSV
using DataFrames
using Graphs
using TulipaEnergyModel
using Test

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

# Add run all test files in test folder
include("test-io.jl")
include("test-time-resolution.jl")
include("test-case-studies.jl")

# Other general tests that don't need their own file
@testset "Ensuring benchmark loads" begin
    include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
    @test SUITE !== nothing
end
