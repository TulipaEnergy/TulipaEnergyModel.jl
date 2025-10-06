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
    # TODO: If would be great to test something about the solution
end

# TODO: Commented out until further discussion
# @testitem "If the window is very large, the solution is the same as no-horizon" setup =
#     [CommonSetup] tags = [:rolling_horizon, :unit] begin
#     connection = DBInterface.connect(DuckDB.DB)
#     _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

#     horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
#         DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
#     )
#     opt_window_length = horizon_length
#     energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
#     expected_objective = energy_problem.objective_value
#     variable_tables = [
#         row.table_name for row in DuckDB.query(
#             connection,
#             "SELECT table_name FROM duckdb_tables() WHERE table_name LIKE 'var%' AND estimated_size > 0",
#         )
#     ]
#     expected_variable_values = Dict(
#         table_name => [
#             row.solution for
#             row in DuckDB.query(connection, "SELECT solution FROM $table_name ORDER BY id")
#         ] for table_name in variable_tables
#     )

#     # DEBUG
#     for table_name in variable_tables
#         DuckDB.query(
#             connection,
#             "CREATE OR REPLACE TABLE diff_$table_name AS (
#                 SELECT id, solution FROM $table_name
#             )",
#         )
#     end

#     col_id = 1
#     for move_forward in [div(horizon_length, k) for k in 3:-1:2]
#         energy_problem =
#             run_rolling_horizon(connection, move_forward, opt_window_length; show_log = false)
#         df_rolling_horizon_window =
#             DataFrame(DuckDB.query(connection, "FROM rolling_horizon_window"))
#         @test df_rolling_horizon_window.objective_value[1] == expected_objective # The first solution should be the full problem
#         for table_name in variable_tables
#             variable_values = [
#                 row.solution for
#                 row in DuckDB.query(connection, "SELECT solution FROM $table_name ORDER BY id")
#             ]
#             # TODO: Note to self: Working on this. This should not be different.
#             # Maybe it is related to move_forward window. Consider running the
#             # ex2 with different move_forward to see the results
#             @info "$table_name" sqrt(
#                 sum((variable_values - expected_variable_values[table_name]) .^ 2),
#             )
#             @test variable_values ≈ expected_variable_values[table_name]

#             # DEBUG
#             DuckDB.query(connection, "ALTER TABLE diff_$table_name ADD COLUMN rolsol$col_id REAL")
#             DuckDB.query(
#                 connection,
#                 "UPDATE diff_$table_name
#                 SET rolsol$col_id = $table_name.solution - diff_$table_name.solution
#                 FROM $table_name
#                 WHERE diff_$table_name.id = $table_name.id",
#             )
#         end
#         global col_id += 1
#     end

#     # DEBUG
#     for table_name in variable_tables
#         @info "DEBUGGING $table_name" DataFrame(
#             DuckDB.query(connection, "SELECT * FROM diff_$table_name WHERE abs(rolsol1) > 1e-8"),
#         )
#     end
# end

@testitem "Correctness of rolling_solution_var_flow" setup = [CommonSetup] tags =
    [:rolling_horizon, :unit] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Rolling Horizon"))

    horizon_length = TEM.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    move_forward = 24
    opt_window_length = horizon_length
    energy_problem = run_rolling_horizon(connection, move_forward, opt_window_length)
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
    @test_logs (:warn, "Model status different from optimal") TEM.run_rolling_horizon(
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

    # Working again with a different opt_window_length
    TEM.run_rolling_horizon(connection, 24, 24 * 5; show_log = false)

    # It should fail when partition is not uniform
    DuckDB.query(
        connection,
        "UPDATE assets_rep_periods_partitions SET partition='4', specification='math' WHERE asset='battery'
        ",
    )
    @test_throws AssertionError TEM.run_rolling_horizon(connection, 24, 48; show_log = false)
end
# Test optionality of the full rolling_solution_var_* tables
