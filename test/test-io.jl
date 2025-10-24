@testitem "Test input validation - missing asset partition if strict" setup = [CommonSetup] tags =
    [:integration, :io, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Norse"))
    @test_throws Exception TulipaEnergyModel.EnergyProblem(connection, strict = true)
end

@testitem "Test output validation - solution files are generated" setup = [CommonSetup] tags =
    [:integration, :io, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Norse"))
    output_folder = mktempdir()
    TulipaEnergyModel.run_scenario(connection; output_folder, show_log = false)
    for filename in (
        "var_flow.csv",
        "var_flows_investment.csv",
        "cons_balance_consumer.csv",
        "cons_capacity_incoming_simple_method.csv",
    )
        @test isfile(joinpath(output_folder, filename))
    end
end

@testitem "Test output validation - saving unsolved energy problem fails" setup = [CommonSetup] tags =
    [:integration, :io, :fast] begin
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

@testitem "Test printing EnergyProblem validation" setup = [CommonSetup] tags =
    [:integration, :io, :fast] begin
    # model infeasible is covered in testset "Infeasible Case Study"
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))

    io = IOBuffer()
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    print(io, energy_problem)
    @test split(String(take!(io))) == split(read("io-outputs/energy-problem-empty.txt", String))

    io = IOBuffer()
    TulipaEnergyModel.create_model!(energy_problem)
    print(io, energy_problem)
    @test split(String(take!(io))) ==
          split(read("io-outputs/energy-problem-model-created.txt", String))

    io = IOBuffer()
    TulipaEnergyModel.solve_model!(energy_problem)
    print(io, energy_problem)
    @test split(String(take!(io))) ==
          split(read("io-outputs/energy-problem-model-solved.txt", String))
end
