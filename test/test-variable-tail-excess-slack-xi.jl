@testitem "Create tail excess slack variable `xi` from test case" setup = [CommonSetup] tags =
    [:unit, :fast, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(
        connection;
        show_log = true,
        model_parameters_file = joinpath(@__DIR__, "inputs", "model-parameters-example-cvar.toml"),
    )
    @test haskey(energy_problem.variables, :tail_excess_slack_xi)
    @test JuMP.lower_bound.(energy_problem.variables[:tail_excess_slack_xi].container) == [0.0]
end

@testitem "Don't create tail excess slack variable `xi` variable" setup = [CommonSetup] tags =
    [:unit, :fast, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    # default parameters have risk_aversion_weight_lambda = 0.0, so no variable should be created
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = true)
    @test haskey(energy_problem.variables, :value_at_risk_threshold_mu)
    @test isempty(energy_problem.variables[:value_at_risk_threshold_mu].container)
end
