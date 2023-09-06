using TulipaEnergyModel
using Test

# Folders names
const INPUT_FOLDER  = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

@testset "TulipaEnergyModel.jl" begin
    parameters, sets = create_parameters_and_sets_from_file(INPUT_FOLDER)
    solution = optimise_investments(parameters, sets)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
    save_solution_to_file(
        OUTPUT_FOLDER,
        sets.s_assets_investment,
        solution.v_investment,
        parameters.p_unit_capacity,
    )
end
