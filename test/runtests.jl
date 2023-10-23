using CSV
using DataFrames
using Graphs
using TulipaEnergyModel
using Test

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")

@testset "TulipaEnergyModel.jl" begin
    dir = joinpath(INPUT_FOLDER, "tiny")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets)
    solution = solve_model(model)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
    save_solution_to_file(
        OUTPUT_FOLDER,
        sets.assets_investment,
        solution.v_investment,
        parameters.assets_unit_capacity,
    )
end

@testset "Infeasible run" begin
    dir = joinpath(INPUT_FOLDER, "tiny")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    parameters.peak_demand["demand"] = -1 # make it infeasible
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets)
    solution = solve_model(model)
    @test solution === nothing
end

@testset "Tiny graph" begin
    @testset "Graph structure is correct" begin
        dir = joinpath(INPUT_FOLDER, "tiny")
        graph =
            create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))

        @test Graphs.nv(graph) == 6
        @test Graphs.ne(graph) == 5
        @test collect(Graphs.edges(graph)) ==
              [Graphs.Edge(e) for e in [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6)]]
    end
end

@testset "Input validation" begin
    @testset "Make sure that input validation fails for bad files" begin
        dir = joinpath(INPUT_FOLDER, "tiny")
        @test_throws ArgumentError TulipaEnergyModel.read_csv_with_schema(
            joinpath(dir, "bad-assets-data.csv"),
            TulipaEnergyModel.AssetData,
        )
    end
end

@testset "Time resolution" begin
    @testset "resolution_matrix" begin
        rp_periods = [1:4, 5:8, 9:12]
        time_steps = [1:4, 5:8, 9:12]
        expected = [
            1.0 0.0 0.0
            0.0 1.0 0.0
            0.0 0.0 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected

        time_steps = [1:3, 4:6, 7:9, 10:12]
        expected = [
            1.0 1/3 0.0 0.0
            0.0 2/3 2/3 0.0
            0.0 0.0 1/3 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected

        time_steps = [1:6, 7:9, 10:10, 11:11, 12:12]
        expected = [
            2/3 0.0 0.0 0.0 0.0
            1/3 2/3 0.0 0.0 0.0
            0.0 1/3 1.0 1.0 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected
    end

    @testset "compute_rp_periods" begin
        # regular
        time_steps1 = [1:4, 5:8, 9:12] # every 4 hours
        time_steps2 = [1:3, 4:6, 7:9, 10:12] # every 3 hours
        time_steps3 = [i:i for i = 1:12] # hourly

        @test compute_rp_periods([time_steps1, time_steps2]) == time_steps1
        @test compute_rp_periods([time_steps1, time_steps2, time_steps3]) == time_steps1
        @test compute_rp_periods([time_steps2, time_steps3]) == time_steps2

        # Irregular
        time_steps4 = [1:6, 7:9, 10:11, 12:12]
        time_steps5 = [1:2, 3:4, 5:12]
        @test compute_rp_periods([time_steps1, time_steps4]) == [1:6, 7:9, 10:12]
        @test compute_rp_periods([time_steps1, time_steps5]) == [1:4, 5:12]
        @test compute_rp_periods([time_steps4, time_steps5]) == [1:6, 7:12]
    end
end
