@testitem "add_rolling_horizon_parameters created Parameters" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))
    energy_problem = EnergyProblem(connection)

    # These Parameters are not there initially
    create_model!(energy_problem; rolling_horizon = false, rolling_horizon_window_length = 24)
    @test all(
        length(p.rolling_horizon_variables) == 0 for p in values(energy_problem.profiles.rep_period)
    )

    # With rolling horizon
    window_length = 24
    TEM.add_rolling_horizon_parameters!(
        energy_problem.db_connection,
        energy_problem.model,
        energy_problem.variables,
        energy_problem.profiles,
        window_length,
    )
    @test all(
        length(p.rolling_horizon_variables) == window_length for
        p in values(energy_problem.profiles.rep_period)
    )
end
