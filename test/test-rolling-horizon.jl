@testitem "Rolling Horizon ..." setup = [CommonSetup] tags = [:rolling_horizon, :unit] begin
    # Test that if the EnergyProblem is created
end

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
    # create_model!(energy_problem; rolling_horizon = true, rolling_horizon_window_length = 24)
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

@testitem "Verify tables created by rolling horizon" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    # Not hardcoding these as they might change when the input changes
    move_forward = 24 * 28 * 3
    maximum_window_length = move_forward * 2
    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    energy_problem = run_rolling_horizon(connection, move_forward, maximum_window_length)

    # Table rolling_horizon_window
    @test "rolling_horizon_window" in
          [row.table_name for row in DuckDB.query(connection, "FROM duckdb_tables()")]

    number_windows = ceil(Int, horizon_length / move_forward)
    df_rolling_horizon_window = DataFrame(DuckDB.query(connection, "FROM rolling_horizon_window"))
    @test maximum(df_rolling_horizon_window.id) == number_windows
    @test sum(df_rolling_horizon_window.opt_window_length) == horizon_length
    # TODO: If would be great to test something about the solution
end

@testitem "If the window is very large, the solution is the same as no-horizon" setup =
    [CommonSetup] tags = [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    # Not hardcoding these as they might change when the input changes
    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    maximum_window_length = horizon_length
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    expected_objective = energy_problem.objective_value

    for move_forward in [div(horizon_length, k) for k in 5:-1:2]
        energy_problem =
            run_rolling_horizon(connection, move_forward, maximum_window_length; show_log = false)
        df_rolling_horizon_window =
            DataFrame(DuckDB.query(connection, "FROM rolling_horizon_window"))
        @test energy_problem.objective_value == expected_objective
    end
end

# Test opt_window = full_window works/fails correctly
# Test that rolling_solution_* tables exist and have the correct number of elements
# Test infeasible rolling problems (what should happen)?
