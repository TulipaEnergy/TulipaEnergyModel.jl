@testset "Input validation" begin
    @testset "Make sure that input validation fails for bad files" begin
        dir = joinpath(INPUT_FOLDER, "Tiny")
        @test_throws ArgumentError TulipaEnergyModel.read_csv_with_schema(
            joinpath(dir, "bad-assets-data.csv"),
            TulipaEnergyModel.schemas.assets.data,
        )
    end

    @testset "Check missing asset partition if strict" begin
        dir = joinpath(INPUT_FOLDER, "Norse")
        @test_throws Exception TulipaEnergyModel.create_energy_problem_from_csv_folder(
            dir,
            strict = true,
        )
    end
end

@testset "Output validation" begin
    @testset "Make sure that saving an unsolved energy problem fails" begin
        energy_problem = create_energy_problem_from_csv_folder(joinpath(INPUT_FOLDER, "Tiny"))
        output_dir = mktempdir()
        @test_throws Exception save_solution_to_file(output_dir, energy_problem)
        create_model!(energy_problem)
        @test_throws Exception save_solution_to_file(output_dir, energy_problem)
        solve_model!(energy_problem)
        @test save_solution_to_file(output_dir, energy_problem) === nothing
    end
end

@testset "Printing EnergyProblem validation" begin
    @testset "Check the missing cases of printing the EnergyProblem" begin # model infeasible is covered in testset "Infeasible Case Study".
        energy_problem = create_energy_problem_from_csv_folder(joinpath(INPUT_FOLDER, "Tiny"))
        print(energy_problem)
        create_model!(energy_problem)
        print(energy_problem)
        solve_model!(energy_problem)
        print(energy_problem)
    end
end

@testset "Graph structure" begin
    @testset "Graph structure is correct" begin
        dir = joinpath(INPUT_FOLDER, "Tiny")
        table_tree = create_input_dataframes_from_csv_folder(dir)
        graph, _, _ = create_internal_structures(table_tree)

        @test Graphs.nv(graph) == 6
        @test Graphs.ne(graph) == 5
        @test collect(Graphs.edges(graph)) ==
              [Graphs.Edge(e) for e in [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6)]]
    end
end

@testset "Test parsing of partitions" begin
    @testset "compute assets partitions" begin
        representative_periods = [
            RepresentativePeriod(Dict(1 => 1.0), 12, 1.0),
            RepresentativePeriod(Dict(2 => 1.0), 24, 1.0),
        ]
        df = DataFrame(
            :asset => [1, 2, 2, 3],
            :rep_period => [1, 1, 2, 2],
            :specification => [:uniform, :explicit, :math, :math],
            :partition => ["3", "4;4;4", "3x4+4x3", "2x2+2x3+2x4+1x6"],
        )
        assets = [1, 2, 3]
        dummy = Dict(a => Dict() for a in assets)
        for a in assets
            compute_assets_partitions!(dummy[a], df, a, representative_periods)
        end
        expected = Dict(
            (1, 1) => [1:3, 4:6, 7:9, 10:12],
            (2, 1) => [1:4, 5:8, 9:12],
            (3, 1) => [i:i for i in 1:12],
            (1, 2) => [i:i for i in 1:24],
            (2, 2) => [1:4, 5:8, 9:12, 13:15, 16:18, 19:21, 22:24],
            (3, 2) => [1:2, 3:4, 5:7, 8:10, 11:14, 15:18, 19:24],
        )
        for a in 1:3, rp in 1:2
            @test dummy[a][rp] == expected[(a, rp)]
        end
    end

    @testset "compute flows partitions" begin
        representative_periods = [
            RepresentativePeriod(Dict(1 => 1.0), 12, 1.0),
            RepresentativePeriod(Dict(2 => 1.0), 24, 1.0),
        ]
        df = DataFrame(
            :from_asset => [1, 2, 2, 3],
            :to_asset => [2, 3, 3, 4],
            :rep_period => [1, 1, 2, 2],
            :specification => [:uniform, :explicit, :math, :math],
            :partition => ["3", "4;4;4", "3x4+4x3", "2x2+2x3+2x4+1x6"],
        )
        flows = [(1, 2), (2, 3), (3, 4)]
        dummy = Dict(f => Dict() for f in flows)
        for (u, v) in flows
            compute_flows_partitions!(dummy[(u, v)], df, u, v, representative_periods)
        end
        expected = Dict(
            ((1, 2), 1) => [1:3, 4:6, 7:9, 10:12],
            ((2, 3), 1) => [1:4, 5:8, 9:12],
            ((3, 4), 1) => [i:i for i in 1:12],
            ((1, 2), 2) => [i:i for i in 1:24],
            ((2, 3), 2) => [1:4, 5:8, 9:12, 13:15, 16:18, 19:21, 22:24],
            ((3, 4), 2) => [1:2, 3:4, 5:7, 8:10, 11:14, 15:18, 19:24],
        )
        for f in flows, rp in 1:2
            @test dummy[f][rp] == expected[(f, rp)]
        end
    end

    @testset "If the math doesn't match, raise exception" begin
        TEM = TulipaEnergyModel
        @test_throws AssertionError TEM._parse_rp_partition(Val(:uniform), "3", 1:13)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:uniform), "3", 1:14)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:explicit), "3;3;3;3", 1:11)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:explicit), "3;3;3;3", 1:13)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:explicit), "3;3;3;3", 1:14)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:math), "3x4", 1:11)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:math), "3x4", 1:13)
        @test_throws AssertionError TEM._parse_rp_partition(Val(:math), "3x4", 1:14)
    end
end

@testset "is_seasonal asset without entry in partitions file should use :uniform,1" begin
    # Copy Norse and delete a row of the partitions file
    dir = mktempdir()
    for (root, _, files) in walkdir(joinpath(INPUT_FOLDER, "Norse"))
        for file in files
            cp(joinpath(root, file), joinpath(dir, file))
        end
    end
    filename = joinpath(dir, "assets-timeframe-partitions.csv")
    lines = readlines(filename)
    open(filename, "w") do io
        for line in lines[1:end-1]
            println(io, line)
        end
    end
    missing_asset = Symbol(split(lines[end], ",")[1]) # The asset the was not included

    table_tree = create_input_dataframes_from_csv_folder(dir)
    graph, rps, tf = create_internal_structures(table_tree)
    @test graph[missing_asset].timeframe_partitions == [i:i for i in 1:tf.num_periods]
end
