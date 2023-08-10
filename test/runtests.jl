using TulipaBulb
using Test

# Folders names
const INPUT_FOLDER  = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

@testset "TulipaBulb.jl" begin
    objective_function = optimise_investments(INPUT_FOLDER, OUTPUT_FOLDER)
    @test objective_function ≈ 269238.43825 atol = 1e-5
end
