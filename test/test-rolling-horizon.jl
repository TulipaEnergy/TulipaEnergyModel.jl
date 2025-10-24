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

@testitem "Verify tables created by rolling horizon" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    # Not hardcoding these as they might change when the input changes
    move_forward = 24
    opt_window_length = move_forward * 2
    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    energy_problem = run_rolling_horizon(connection, move_forward, opt_window_length)

    # Table rolling_horizon_window
    @test "rolling_horizon_window" in
          [row.table_name for row in DuckDB.query(connection, "FROM duckdb_tables()")]

    number_of_windows = ceil(Int, horizon_length / move_forward)
    df_rolling_horizon_window = DataFrame(DuckDB.query(connection, "FROM rolling_horizon_window"))
    @test maximum(df_rolling_horizon_window.id) == number_of_windows
    @test sum(df_rolling_horizon_window.move_forward) == horizon_length
end

@testitem "If the optimisation window is very large, the first rolling solution is the same as no-horizon" setup =
    [CommonSetup] tags = [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    opt_window_length = horizon_length
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    expected_objective = energy_problem.objective_value

    for move_forward in [div(horizon_length, k) for k in (2, 3, 4, 6, 12, 24)]
        energy_problem =
            run_rolling_horizon(connection, move_forward, opt_window_length; show_log = false)
        df_rolling_horizon_window =
            DataFrame(DuckDB.query(connection, "FROM rolling_horizon_window"))
        @test df_rolling_horizon_window.objective_value[1] == expected_objective # The first solution should be the full problem
    end
end

@testitem "Correctness of rolling_solution_var_flow" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    move_forward = 24
    opt_window_length = horizon_length
    energy_problem = run_rolling_horizon(
        connection,
        move_forward,
        opt_window_length;
        save_rolling_solution = true,
    )
    number_of_windows = ceil(Int, horizon_length / move_forward)

    @test "rolling_solution_var_flow" in
          [row.table_name for row in DuckDB.query(connection, "FROM duckdb_tables()")]

    df_rolsol_var_flow = DataFrame(DuckDB.query(connection, "FROM rolling_solution_var_flow"))
    # All window_ids are there
    @test sort(unique(df_rolsol_var_flow.window_id)) == 1:number_of_windows
    # All variable ids are there
    number_of_flows = TEM.get_num_rows(connection, "flow")
    expected_number_of_var_flow = move_forward * number_of_flows * number_of_windows # 1 year, 1 rp
    @test sort(unique(df_rolsol_var_flow.var_id)) == 1:expected_number_of_var_flow
end

@testitem "Test infeasible rolling horizon nice end" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    DuckDB.execute( # Make it infeasible
        connection,
        "UPDATE asset_milestone SET peak_demand = 1500",
    )
    @test_logs (:warn, "Model status different from optimal") match_mode = :any TEM.run_rolling_horizon(
        connection,
        24,
        48,
        show_log = false,
    )
    energy_problem = TEM.run_rolling_horizon(connection, 24, 48; show_log = false)
    @test energy_problem.termination_status == JuMP.INFEASIBLE
end

# Test validation of time resolution (uniform and resolutions are divisors of move_forward)
@testitem "Test that opt_window_length must be divisible by all time resolutions and that they are uniform" setup =
    [CommonSetup] tags = [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    # First, it should allow more complex resolutions
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TABLE assets_rep_periods_partitions (
            asset TEXT,
            specification TEXT,
            partition TEXT,
            year INT,
            rep_period INT
        );
        INSERT INTO assets_rep_periods_partitions (asset, specification, partition, year, rep_period)
            VALUES
                ('solar',   'uniform', '2', 2030, 1),
                ('thermal', 'uniform', '3', 2030, 1),
                ('battery', 'uniform', '4', 2030, 1),
                ('demand',  'uniform', '6', 2030, 1),
        ",
    )
    energy_problem = TEM.run_rolling_horizon(connection, 24, 48; show_log = false)

    # It should fail when opt_window_length is not a multiple of any of these
    DuckDB.query(
        connection,
        "UPDATE assets_rep_periods_partitions SET partition='5' WHERE asset='battery'
        ",
    )
    @test_throws AssertionError TEM.run_rolling_horizon(connection, 24, 48; show_log = false)

    # Working again with different move_forward and opt_window_length that are divisible by 5
    TEM.run_rolling_horizon(connection, 12 * 5, 24 * 5; show_log = false)

    # It should fail when partition is not uniform
    DuckDB.query(
        connection,
        "UPDATE assets_rep_periods_partitions SET partition='4', specification='math' WHERE asset='battery'
        ",
    )
    @test_throws AssertionError TEM.run_rolling_horizon(connection, 24, 48; show_log = false)
end

# Test optionality of the full rolling_solution_var_* tables
@testitem "Test option save_rolling_solution" setup = [CommonSetup] tags = [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    TEM.run_rolling_horizon(connection, 24, 48; show_log = false, save_rolling_solution = false)
    tables = [row.table_name for row in DuckDB.query(connection, "FROM duckdb_tables")]
    @test !("rolling_solution_var_flow" in tables)
    TEM.run_rolling_horizon(connection, 24, 48; show_log = false, save_rolling_solution = true)
    tables = [row.table_name for row in DuckDB.query(connection, "FROM duckdb_tables")]
    @test "rolling_solution_var_flow" in tables
end

@testitem "Test internal rolling_horizon_energy_problem" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    # There is no internal rolling_horizon_energy_problem when we're not running rolling_horizon
    energy_problem = TEM.run_scenario(connection; show_log = false)
    @test isnothing(energy_problem.rolling_horizon_energy_problem)
    @test !isnan(energy_problem.objective_value)

    # Now there will be one
    energy_problem = TEM.run_rolling_horizon(connection, 24, 48; show_log = false)
    @test energy_problem.rolling_horizon_energy_problem isa EnergyProblem
    @test isnan(energy_problem.objective_value)
    @test !isnan(energy_problem.rolling_horizon_energy_problem.objective_value)
end

@testitem "Test exporting output of rolling horizon to CSV works" setup = [CommonSetup] tags =
    [:integration, :io, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))
    output_folder = mktempdir()
    TulipaEnergyModel.run_rolling_horizon(connection, 24, 48; output_folder, show_log = false)
    for filename in
        ("var_flow.csv", "cons_balance_consumer.csv", "cons_capacity_incoming_simple_method.csv")
        @test isfile(joinpath(output_folder, filename))
    end
end
