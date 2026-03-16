@testitem "Create value-at-risk threshold `μ` variable from test case" setup = [CommonSetup] tags =
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
    @test haskey(energy_problem.variables, :value_at_risk_threshold_mu)
    @test JuMP.lower_bound.(energy_problem.variables[:value_at_risk_threshold_mu].container) ==
          [0.0]
end

@testitem "Don't create value-at-risk threshold `μ` variable" setup = [CommonSetup] tags =
    [:unit, :fast, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    # default parameters have risk_aversion_weight_lambda = 0.0, so no variable  should be created
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test !haskey(energy_problem.variables, :value_at_risk_threshold_mu)
end
