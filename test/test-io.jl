@testset "Input validation" begin
    @testset "Check missing asset partition if strict" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Norse"))
        @test_throws Exception TulipaEnergyModel.EnergyProblem(connection, strict = true)
    end
end

@testset "Output validation" begin
    @testset "Make sure that saving an unsolved energy problem fails" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        output_dir = mktempdir()
        @test_throws Exception TulipaEnergyModel.save_solution_to_file(output_dir, energy_problem)
        TulipaEnergyModel.create_model!(energy_problem)
        @test_throws Exception TulipaEnergyModel.save_solution_to_file(output_dir, energy_problem)
        TulipaEnergyModel.solve_model!(energy_problem)
        @test TulipaEnergyModel.save_solution_to_file(output_dir, energy_problem) === nothing
    end
end

@testset "Printing EnergyProblem validation" begin
    @testset "Check the missing cases of printing the EnergyProblem" begin # model infeasible is covered in testset "Infeasible Case Study".
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        print(energy_problem)
        TulipaEnergyModel.create_model!(energy_problem)
        print(energy_problem)
        TulipaEnergyModel.solve_model!(energy_problem)
        print(energy_problem)
    end
end

@testset "Graph structure" begin
    @testset "Graph structure is correct" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        graph, _, _ = TulipaEnergyModel.create_internal_structures(connection)

        @test Graphs.nv(graph) == 6
        @test Graphs.ne(graph) == 5
        @test collect(Graphs.edges(graph)) ==
              [Graphs.Edge(e) for e in [(1, 2), (3, 2), (4, 2), (5, 2), (6, 2)]]
    end
end
