@testset "Input validation" begin
    @testset "Check missing asset partition if strict" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Norse"))
        @test_throws Exception TulipaEnergyModel.EnergyProblem(connection, strict = true)
    end
end

@testset "Output validation" begin
    @testset "Check that solution files are generated" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Norse"))
        TulipaEnergyModel.run_scenario(connection; output_folder = joinpath(OUTPUT_FOLDER))
        for filename in (
            "var_flow.csv",
            "var_flows_investment.csv",
            "cons_balance_consumer.csv",
            "cons_capacity_incoming.csv",
        )
            @test isfile(joinpath(OUTPUT_FOLDER, filename))
        end
    end

    @testset "Make sure that saving an unsolved energy problem fails" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        output_dir = mktempdir()
        @test_throws Exception TulipaEnergyModel.export_solution_to_csv_files(
            output_dir,
            energy_problem,
        )
        TulipaEnergyModel.create_model!(energy_problem)
        @test_throws Exception TulipaEnergyModel.export_solution_to_csv_files(
            output_dir,
            energy_problem,
        )
        TulipaEnergyModel.solve_model!(energy_problem)
        @test TulipaEnergyModel.export_solution_to_csv_files(output_dir, energy_problem) === nothing
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
