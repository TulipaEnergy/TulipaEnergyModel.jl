@testsnippet DemandResponseSetup begin
    # Enable demand response on the `demand` consumer of the Tiny dataset and
    # return a ready-to-use connection.
    function _dr_tiny_fixture(;
        max_shift_fraction = 0.2,
        transaction_cost = 0.0,
        window_blocks = 2,
    )
        dir = joinpath(INPUT_FOLDER, "Tiny")
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        DuckDB.query(
            connection,
            "UPDATE asset
             SET demand_response_method = 'shifting_with_recovery'
             WHERE asset = 'demand'",
        )
        DuckDB.query(
            connection,
            "UPDATE asset_milestone
             SET dr_max_shift_fraction = $max_shift_fraction,
                 dr_transaction_cost = $transaction_cost,
                 dr_window_blocks = $window_blocks
             WHERE asset = 'demand'",
        )
        return connection
    end

    # Enable demand response on the `demand` consumer of the Variable Resolution
    # dataset and return a ready-to-use connection.
    #
    # In this dataset, the flow balance→demand has a `uniform,3` partition:
    #   Block 1: timesteps 1–3  (duration = 3 timesteps = 3 h at resolution 1 h/timestep)
    #   Block 2: timesteps 4–6  (duration = 3 timesteps)
    # So DR operates on 2 blocks per representative period, not on 6 hourly blocks.
    # This makes it the canonical fixture for testing that dr_window_blocks counts
    # blocks (not hours) and that block-duration weighting in the window recovery
    # constraint is correct.
    function _dr_variable_resolution_fixture(;
        max_shift_fraction = 0.3,
        transaction_cost = 0.0,
        window_blocks = 2,
    )
        dir = joinpath(INPUT_FOLDER, "Variable Resolution")
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        DuckDB.query(
            connection,
            "UPDATE asset
             SET demand_response_method = 'shifting_with_recovery'
             WHERE asset = 'demand'",
        )
        DuckDB.query(
            connection,
            "UPDATE asset_milestone
             SET dr_max_shift_fraction = $max_shift_fraction,
                 dr_transaction_cost = $transaction_cost,
                 dr_window_blocks = $window_blocks
             WHERE asset = 'demand'",
        )
        return connection
    end
end

@testitem "Demand response disabled leaves the model unchanged" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # Baseline Tiny run (no demand response)
    dir = joinpath(INPUT_FOLDER, "Tiny")
    baseline_connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(baseline_connection, dir)
    baseline = TulipaEnergyModel.EnergyProblem(baseline_connection)
    TulipaEnergyModel.create_model!(baseline)
    TulipaEnergyModel.solve_model!(baseline)

    # No demand response variables should exist when the method is 'none'
    n_dr = only(
        DuckDB.query(
            baseline_connection,
            "SELECT COUNT(*) AS n FROM var_dr_demand_increase",
        ),
    ).n
    @test n_dr == 0
    @test baseline.objective_value !== nothing
end

@testitem "Demand response variables and windows are created" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    connection = _dr_tiny_fixture(; window_blocks = 2)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)

    n_inc = only(
        DuckDB.query(connection, "SELECT COUNT(*) AS n FROM var_dr_demand_increase"),
    ).n
    n_dec = only(
        DuckDB.query(connection, "SELECT COUNT(*) AS n FROM var_dr_demand_decrease"),
    ).n
    @test n_inc > 0
    @test n_inc == n_dec

    # Number of windows equals ceil(n_blocks / window_blocks) per (year, rep_period)
    n_windows = only(
        DuckDB.query(connection, "SELECT COUNT(*) AS n FROM cons_dr_window_balance"),
    ).n
    expected_windows = only(
        DuckDB.query(
            connection,
            "WITH counts AS (
                SELECT asset, milestone_year, rep_period, COUNT(*) AS n_blocks
                FROM var_dr_demand_increase
                GROUP BY asset, milestone_year, rep_period
            )
            SELECT SUM(CEIL(n_blocks::DOUBLE / 2)) AS n FROM counts",
        ),
    ).n
    @test n_windows == expected_windows
end

@testitem "Demand response solves and net-zero window recovery holds" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    connection = _dr_tiny_fixture(; max_shift_fraction = 0.3, window_blocks = 2)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)
    @test JuMP.termination_status(energy_problem.model) == JuMP.MOI.OPTIMAL

    # The recovery windows enforce net-zero shifted energy
    for cons in energy_problem.model[:dr_window_balance]
        @test JuMP.normalized_rhs(cons) == 0.0
    end
end

@testitem "Demand response with flexibility does not increase cost" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # Baseline
    dir = joinpath(INPUT_FOLDER, "Tiny")
    baseline_connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(baseline_connection, dir)
    baseline = TulipaEnergyModel.EnergyProblem(baseline_connection)
    TulipaEnergyModel.create_model!(baseline)
    TulipaEnergyModel.solve_model!(baseline)

    # With demand response (no transaction cost) the objective cannot be worse
    connection = _dr_tiny_fixture(; max_shift_fraction = 0.3, transaction_cost = 0.0)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)

    @test energy_problem.objective_value <= baseline.objective_value + 1e-6
end

@testitem "Validation rejects demand response on non-consumer assets" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        "UPDATE asset
         SET demand_response_method = 'shifting_with_recovery'
         WHERE asset = 'ccgt'",
    )
    error_messages = TEM._validate_demand_response!(String[], connection)
    @test length(error_messages) > 0
    @test any(occursin("consumer", msg) for msg in error_messages)
end

@testitem "Validation rejects out-of-range demand response parameters" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        "UPDATE asset
         SET demand_response_method = 'shifting_with_recovery'
         WHERE asset = 'demand'",
    )
    DuckDB.query(
        connection,
        "UPDATE asset_milestone
         SET dr_max_shift_fraction = 1.5, dr_window_blocks = 0
         WHERE asset = 'demand'",
    )
    error_messages = TEM._validate_demand_response!(String[], connection)
    @test length(error_messages) > 0
end

# ── Variable-resolution DR tests ──────────────────────────────────────────────
#
# The Variable Resolution dataset has the flow balance→demand partitioned as
# `uniform,3`: two DR blocks per representative period ([1–3] and [4–6]), each
# spanning 3 timesteps × 1 h/timestep = 3 h.
#
# These tests verify that dr_window_blocks is counted in DR *blocks*, not in
# raw timesteps or hours. Concretely, dr_window_blocks = 2 means "two 3-h
# blocks" = one 6-h recovery window, not "two 1-h timesteps".
#
# If anyone changes how DR indices are built (e.g., switching from
# t_highest_all_flows to a different resolution source) these tests will catch
# the regression.

@testitem "DR variable resolution: blocks follow flow partition, not raw timesteps" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # The balance→demand flow has a `uniform,3` partition. That creates 2 blocks
    # [1–3] and [4–6] (6 total timesteps / 3 per block = 2 blocks).
    # DR variables must mirror those blocks – they must NOT be 6 hourly entries.
    connection = _dr_variable_resolution_fixture(; window_blocks = 1)
    TulipaEnergyModel.EnergyProblem(connection)   # runs index creation

    rows = collect(DuckDB.query(
        connection,
        "SELECT time_block_start, time_block_end,
                time_block_end - time_block_start + 1 AS block_len
         FROM var_dr_demand_increase
         ORDER BY time_block_start",
    ))

    @test length(rows) == 2                           # 2 blocks, not 6 hourly
    @test rows[1].time_block_start == 1
    @test rows[1].time_block_end == 3
    @test rows[1].block_len == 3                      # 3-timestep block (= 3 h)
    @test rows[2].time_block_start == 4
    @test rows[2].time_block_end == 6
    @test rows[2].block_len == 3
end

@testitem "DR variable resolution: window_blocks counts blocks, not hours" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # With 2 DR blocks and dr_window_blocks = 2, there should be exactly
    # 1 recovery window covering the entire representative period [1–6].
    # If the implementation counted timesteps instead of blocks, it would
    # create 3 windows of 2 timesteps each – this test would catch that.
    connection = _dr_variable_resolution_fixture(; window_blocks = 2)
    TulipaEnergyModel.EnergyProblem(connection)

    windows = collect(DuckDB.query(
        connection,
        "SELECT time_block_start, time_block_end
         FROM cons_dr_window_balance
         ORDER BY time_block_start",
    ))

    @test length(windows) == 1                  # 1 window (ceil(2 blocks / 2) = 1)
    @test windows[1].time_block_start == 1      # starts at first timestep
    @test windows[1].time_block_end == 6        # ends at last timestep of the RP
end

@testitem "DR variable resolution: window balance uses block duration as weight" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # Each 3-timestep block contributes a weight of 3 in the net-zero sum:
    #   ∑_b (d+_b – d-_b) · Δ_b = 0   where Δ_b = 3 for both blocks.
    # After solving, the window constraint RHS must be 0.0 (net-zero shifted energy).
    connection = _dr_variable_resolution_fixture(; max_shift_fraction = 0.3, window_blocks = 2)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)

    @test JuMP.termination_status(energy_problem.model) == JuMP.MOI.OPTIMAL

    # All window-balance constraints must enforce net zero (RHS = 0).
    for cons in energy_problem.model[:dr_window_balance]
        @test JuMP.normalized_rhs(cons) == 0.0
    end

    # Verify post-solve that the solved values respect net-zero per window.
    TulipaEnergyModel.save_solution!(energy_problem)
    net_by_window = collect(DuckDB.query(
        connection,
        "SELECT w.window_id,
                SUM((COALESCE(i.solution, 0.0) - COALESCE(d.solution, 0.0))
                    * (i.time_block_end - i.time_block_start + 1)) AS net_mwh
         FROM cons_dr_window_balance AS w
         JOIN var_dr_demand_increase AS i
           ON i.asset = w.asset AND i.milestone_year = w.milestone_year
          AND i.rep_period = w.rep_period
          AND i.time_block_start >= w.time_block_start
          AND i.time_block_end   <= w.time_block_end
         JOIN var_dr_demand_decrease AS d ON d.id = i.id
         GROUP BY w.window_id",
    ))

    for row in net_by_window
        @test abs(row.net_mwh) < 1e-6
    end
end

@testitem "DR variable resolution: enabling DR does not increase cost" setup =
    [CommonSetup, DemandResponseSetup] tags = [:integration, :fast] begin
    # Baseline Variable Resolution run (no DR).
    dir = joinpath(INPUT_FOLDER, "Variable Resolution")
    baseline_connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(baseline_connection, dir)
    baseline = TulipaEnergyModel.EnergyProblem(baseline_connection)
    TulipaEnergyModel.create_model!(baseline)
    TulipaEnergyModel.solve_model!(baseline)

    # DR-enabled run: free flexibility must not increase cost.
    connection = _dr_variable_resolution_fixture(; max_shift_fraction = 0.3, transaction_cost = 0.0)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)

    @test energy_problem.objective_value <= baseline.objective_value + 1e-6
end
