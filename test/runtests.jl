using Graphs
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

@testset "Tiny graph" begin
    @testset "Graph structure is correct" begin
        dir = joinpath(INPUT_FOLDER, "tiny")
        graph =
            create_graph(joinpath(dir, "nodes-data.csv"), joinpath(dir, "edges-data.csv"))

        @test Graphs.nv(graph) == 6
        @test Graphs.ne(graph) == 5
        @test collect(Graphs.edges(graph)) ==
              [Graphs.Edge(e) for e in [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6)]]
    end
end
