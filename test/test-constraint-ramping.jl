@testsnippet ConsRampingSetup begin
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_ramping_problem(;
        unit_commitment = "none",
        initial_units = 10.0,
        capacity = 100.0,
        min_operating_point = 0.0,
        max_ramp_up = 0.5,
        max_ramp_down = 0.5,
        num_timesteps = 3,
        partition = 1,
    )
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "demand", :consumer; peak_demand = 1000.0)
        TB.add_asset!(
            tulipa,
            "plant",
            :producer;
            capacity,
            initial_units,
            min_operating_point,
            ramping = true,
            max_ramp_up,
            max_ramp_down,
            unit_commitment,
            unit_commitment_integer = true,
        )
        TB.add_flow!(tulipa, "plant", "demand")
        TB.attach_profile!(tulipa, "plant", :availability, 2030, ones(num_timesteps); scenario = 1)

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, num_timesteps, 1; layout)
        if partition > 1
            DuckDB.query(
                connection,
                """CREATE OR REPLACE TABLE assets_rep_periods_partitions AS
                   SELECT * FROM (VALUES
                       ('plant', 2030, 1, '$partition', 'uniform')
                   ) AS partitions(asset, milestone_year, rep_period, partition, specification)""",
            )
            DuckDB.query(
                connection,
                """CREATE OR REPLACE TABLE flows_rep_periods_partitions AS
                   SELECT * FROM (VALUES
                       ('plant', 'demand', 2030, 1, '$partition', 'uniform')
                   ) AS partitions(from_asset, to_asset, milestone_year, rep_period, partition, specification)""",
            )
        end
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)
        return connection, energy_problem
    end
end

@testitem "Non-UC ramping scales with available units" setup = [CommonSetup, ConsRampingSetup] tags =
    [:unit, :constraint, :fast] begin
    connection, energy_problem = create_ramping_problem()
    model = energy_problem.model

    rows =
        energy_problem.constraints[:max_ramp_without_unit_commitment_aggregated_vintage_method].indices
    @test length(collect(rows)) == 3
    @test isempty(
        collect(
            DuckDB.query(
                connection,
                """SELECT id FROM cons_max_ramp_without_unit_commitment_compact_vintage_method""",
            ),
        ),
    )

    up_constraints = model[:max_ramp_up_without_unit_commitment_aggregated_vintage_method]
    down_constraints = model[:max_ramp_down_without_unit_commitment_aggregated_vintage_method]
    @test JuMP.constraint_object(up_constraints[2]).set.upper ≈ 500.0
    @test JuMP.constraint_object(down_constraints[2]).set.lower ≈ -500.0
end

@testitem "UC assets are excluded from non-UC ramping" setup = [CommonSetup, ConsRampingSetup] tags =
    [:unit, :constraint, :fast] begin
    connection, energy_problem =
        create_ramping_problem(; unit_commitment = "basic", initial_units = 1.0)
    @test isempty(
        collect(
            DuckDB.query(
                connection,
                """SELECT id FROM cons_max_ramp_without_unit_commitment_aggregated_vintage_method""",
            ),
        ),
    )
    @test length(collect(energy_problem.constraints[:max_ramp_with_unit_commitment].indices)) == 3
end

@testitem "Clustered UC ramping limits start-up and shut-down output" setup =
    [CommonSetup, ConsRampingSetup] tags = [:unit, :constraint, :fast] begin
    _, energy_problem = create_ramping_problem(;
        unit_commitment = "basic",
        initial_units = 2.0,
        capacity = 200.0,
        min_operating_point = 0.75,
        max_ramp_up = 0.1,
        max_ramp_down = 0.1,
    )
    model = energy_problem.model
    cons = energy_problem.constraints[:max_ramp_with_unit_commitment]
    units_on = cons.expressions[:units_on]
    flow_above_min = cons.expressions[:flow_above_min_operating_point]

    expected_start_up = JuMP.@build_constraint(
        flow_above_min[2] <= 200.0 * (0.1 * units_on[2] + 0.15 * units_on[1])
    )
    @test _verify_constraint_using_id(model, :max_output_flow_during_start_up, 2, expected_start_up)

    expected_shut_down = JuMP.@build_constraint(
        flow_above_min[1] <= 200.0 * (0.1 * units_on[1] + 0.15 * units_on[2])
    )
    @test _verify_constraint_using_id(
        model,
        :max_output_flow_during_shut_down,
        2,
        expected_shut_down,
    )
end

@testitem "Clustered UC ramping scales and clamps flexible blocks" setup =
    [CommonSetup, ConsRampingSetup] tags = [:unit, :constraint, :fast] begin
    _, energy_problem = create_ramping_problem(;
        unit_commitment = "3var",
        initial_units = 2.0,
        capacity = 200.0,
        min_operating_point = 0.75,
        max_ramp_up = 0.1,
        max_ramp_down = 0.2,
        num_timesteps = 4,
        partition = 2,
    )
    model = energy_problem.model
    cons = energy_problem.constraints[:max_ramp_with_unit_commitment]
    units_on = cons.expressions[:units_on]
    flow_above_min = cons.expressions[:flow_above_min_operating_point]

    expected_start_up = JuMP.@build_constraint(
        flow_above_min[2] <= 200.0 * (0.2 * units_on[2] + 0.05 * units_on[1])
    )
    @test _verify_constraint_using_id(model, :max_output_flow_during_start_up, 2, expected_start_up)

    expected_shut_down = JuMP.@build_constraint(flow_above_min[1] <= 200.0 * 0.25 * units_on[1])
    @test _verify_constraint_using_id(
        model,
        :max_output_flow_during_shut_down,
        2,
        expected_shut_down,
    )
end

@testitem "Compact-vintage ramping uses available vintages" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = _multi_year_fixture()
    DuckDB.query(
        connection,
        """UPDATE asset
           SET ramping = true, max_ramp_up = 0.5, max_ramp_down = 0.5
           WHERE asset IN ('wind', 'ccgt')""",
    )
    DuckDB.query(
        connection,
        """UPDATE profiles_rep_periods
           SET value = CASE profile_name
               WHEN 'availability-wind2020' THEN 0.2
               WHEN 'availability-wind2030' THEN 0.5
           END
           WHERE milestone_year = 2030
               AND profile_name IN ('availability-wind2020', 'availability-wind2030')""",
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    model = energy_problem.model
    cons = energy_problem.constraints[:max_ramp_without_unit_commitment_compact_vintage_method]
    investment_id = only(DuckDB.query(
        connection,
        """SELECT id FROM var_assets_investment
           WHERE asset = 'wind' AND milestone_year = 2030""",
    )).id
    decommission_id = only(
        DuckDB.query(
            connection,
            """SELECT id FROM var_assets_decommission
               WHERE asset = 'wind' AND milestone_year = 2030 AND commission_year = 2020""",
        ),
    ).id
    investment = energy_problem.variables[:assets_investment].container[investment_id]
    decommission = energy_problem.variables[:assets_decommission].container[decommission_id]

    for (asset, ramp_limit) in (
        ("wind", JuMP.@expression(model, 0.6 + 12.5 * investment - 5.0 * decommission)),
        ("ccgt", 400.0),
    )
        rows = collect(
            DuckDB.query(
                connection,
                """SELECT id, time_block_start, time_block_end
                   FROM cons_max_ramp_without_unit_commitment_compact_vintage_method
                   WHERE asset = '$asset' AND milestone_year = 2030 AND rep_period = 1
                       AND time_block_start IN (1, 2)
                   ORDER BY time_block_start""",
            ),
        )
        previous, current = rows
        @test (previous.time_block_start, previous.time_block_end) == (1, 1)
        @test (current.time_block_start, current.time_block_end) == (2, 2)
        @test cons.coefficients[:min_outgoing_flow_duration][current.id] == 1.0
        outgoing = cons.expressions[:outgoing]
        expected_up =
            JuMP.@build_constraint(outgoing[current.id] - outgoing[previous.id] <= ramp_limit)
        expected_down =
            JuMP.@build_constraint(outgoing[current.id] - outgoing[previous.id] >= -ramp_limit)
        @test _verify_constraint_using_id(
            model,
            :max_ramp_up_without_unit_commitment_compact_vintage_method,
            current.id,
            expected_up,
        )
        @test _verify_constraint_using_id(
            model,
            :max_ramp_down_without_unit_commitment_compact_vintage_method,
            current.id,
            expected_down,
        )
    end
end
