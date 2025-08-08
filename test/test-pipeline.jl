@testitem "Test pipeline from beginning to end with EnergyProblem struct" setup = [CommonSetup] tags =
    [:integration, :pipeline, :fast] begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)
    TulipaEnergyModel.export_solution_to_csv_files(mktempdir(), energy_problem)
end

@testsnippet PipelineSetup begin
    function run_full_pipeline_test(input_name)
        # Data loading
        dir = joinpath(INPUT_FOLDER, input_name)
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)

        # Internal data and structures pre-model
        TulipaEnergyModel.create_internal_tables!(connection)
        model_parameters = TulipaEnergyModel.ModelParameters(connection)
        variables = TulipaEnergyModel.compute_variables_indices(connection)
        constraints = TulipaEnergyModel.compute_constraints_indices(connection)
        profiles = TulipaEnergyModel.prepare_profiles_structure(connection)

        # Create model
        model, expressions = TulipaEnergyModel.create_model(
            connection,
            variables,
            constraints,
            profiles,
            model_parameters,
        )

        # Solve model
        TulipaEnergyModel.solve_model(model)
        TulipaEnergyModel.save_solution!(connection, model, variables, constraints)
        output_dir = mktempdir()
        TulipaEnergyModel.export_solution_to_csv_files(
            output_dir,
            connection,
            variables,
            constraints,
        )
        return true
    end
end

@testitem "Test pipeline from beginning to end without EnergyProblem struct - Tiny" setup =
    [CommonSetup, PipelineSetup] tags = [:integration, :pipeline, :fast] begin
    @test run_full_pipeline_test("Tiny")
end

@testitem "Test pipeline from beginning to end without EnergyProblem struct - Norse" setup =
    [CommonSetup, PipelineSetup] tags = [:integration, :pipeline, :fast] begin
    @test run_full_pipeline_test("Norse")
end

@testitem "Test pipeline from beginning to end without EnergyProblem struct - Variable Resolution" setup =
    [CommonSetup, PipelineSetup] tags = [:integration, :pipeline, :fast] begin
    @test run_full_pipeline_test("Variable Resolution")
end

@testitem "Test pipeline from beginning to end without EnergyProblem struct - Multi-year Investments" setup =
    [CommonSetup, PipelineSetup] tags = [:integration, :pipeline, :fast] begin
    @test run_full_pipeline_test("Multi-year Investments")
end

@testitem "Test pipeline starting with simplest data and using populate_with_defaults!" setup =
    [CommonSetup, TestData] tags = [:integration, :pipeline, :fast] begin
    # Most basic version of data
    connection = _create_connection_from_dict(TestData.simplest_data)

    # Fix missing columns
    TulipaEnergyModel.populate_with_defaults!(connection)

    # Test that it doesn't fail
    energy_problem =
        TulipaEnergyModel.run_scenario(connection; show_log = false, output_folder = mktempdir())
end
