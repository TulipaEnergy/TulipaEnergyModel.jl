@testsnippet ConsStorageMinMaxLevelSetup begin
    using DuckDB: DuckDB
    using Statistics: mean
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_storage_bounds_problem(;
        assets = Tuple[],
        num_timesteps::Int = 2,
        num_rep_periods::Int = 2,
    )
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "consumer", :consumer)

        for asset in assets
            TB.add_asset!(
                tulipa,
                asset.name,
                :storage;
                use_inter_period_constraints = asset.use_inter_period_constraints,
                inter_period_storage_level_bounds = get(asset, :bounds, "inter_period_only"),
                initial_units = 2.0,
                initial_storage_units = 3.0,
                initial_storage_level = get(asset, :initial_storage_level, missing),
                capacity = 5.0,
                capacity_storage_energy = 47.0,
                storage_method_energy = get(asset, :storage_method_energy, "none"),
                energy_to_power_ratio = 7.0,
                investable = get(asset, :investable, false),
                vintage_method = "aggregated",
                storage_loss_from_stored_energy = get(asset, :storage_loss, 0.0),
            )
            TB.add_flow!(tulipa, "consumer", asset.name)
            TB.add_flow!(tulipa, asset.name, "consumer")
            TB.attach_profile!(
                tulipa,
                asset.name,
                :inflows,
                2030,
                get(asset, :inflows_profile, [0.1, 0.2, 0.3, 0.4]),
            )

            for (profile_type, key) in
                ((:max_storage_level, :max_profile), (:min_storage_level, :min_profile))
                profile = get(asset, key, nothing)
                if isnothing(profile)
                    continue
                end
                if asset.use_inter_period_constraints
                    TB.attach_timeframe_profile!(tulipa, asset.name, profile_type, 2030, profile)
                else
                    TB.attach_profile!(tulipa, asset.name, profile_type, 2030, profile)
                end
            end
        end

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, num_timesteps, num_rep_periods; layout)
        partition_rows = [
            (asset.name, Int32(2030), string(get(asset, :timeframe_partition, 1)), "uniform")
            for asset in assets
        ]
        _create_table_for_tests(
            connection,
            "assets_timeframe_partitions",
            partition_rows,
            [:asset, :milestone_year, :partition, :specification],
        )
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)
        return energy_problem
    end

    function constraint_assets(connection, table_name::Symbol)
        return Set(
            row.asset for row in
            DuckDB.query(connection, "SELECT DISTINCT asset FROM cons_$table_name ORDER BY asset")
        )
    end

    function expected_rep_period_bounds(energy_problem)
        connection = energy_problem.db_connection
        capacity =
            energy_problem.expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]
        level = energy_problem.variables[:storage_level_intra_rep_period].container

        max_rows = TEM._append_storage_level_intra_rep_period_bound_data_to_indices(
            connection,
            :max_storage_level_intra_rep_period_limit,
        )
        expected_max = [
            begin
                profile = TEM._profile_aggregate(
                    energy_problem.profiles.rep_period,
                    (row.max_storage_level_profile_name, row.milestone_year, row.rep_period),
                    row.time_block_start:row.time_block_end,
                    mean,
                    1.0,
                )
                JuMP.@build_constraint(
                    level[row.storage_level_id] <= profile * capacity[row.avail_energy_capacity_id]
                )
            end for row in max_rows
        ]

        min_rows = TEM._append_storage_level_intra_rep_period_bound_data_to_indices(
            connection,
            :min_storage_level_intra_rep_period_limit,
        )
        expected_min = [
            begin
                profile = TEM._profile_aggregate(
                    energy_problem.profiles.rep_period,
                    (row.min_storage_level_profile_name, row.milestone_year, row.rep_period),
                    row.time_block_start:row.time_block_end,
                    mean,
                    0.0,
                )
                JuMP.@build_constraint(
                    level[row.storage_level_id] >= profile * capacity[row.avail_energy_capacity_id]
                )
            end for row in min_rows
        ]
        return (expected_max, expected_min)
    end
end

@testitem "Representative-period storage bounds and capacity methods" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_storage_bounds_problem(;
        assets = [
            (;
                name = "fixed",
                use_inter_period_constraints = false,
                max_profile = fill(0.8, 4),
                min_profile = fill(0.2, 4),
            ),
            (;
                name = "optimized",
                use_inter_period_constraints = false,
                storage_method_energy = "optimize_storage_capacity",
                investable = true,
                max_profile = fill(0.7, 4),
                min_profile = fill(0.1, 4),
            ),
            (;
                name = "ratio",
                use_inter_period_constraints = false,
                storage_method_energy = "use_fixed_energy_to_power_ratio",
                investable = true,
                max_profile = fill(0.9, 4),
                min_profile = fill(0.3, 4),
            ),
        ],
    )

    expected_max, expected_min = expected_rep_period_bounds(energy_problem)
    @test _is_constraint_equal(
        expected_max,
        _get_cons_object(energy_problem.model, :max_storage_level_intra_rep_period_limit),
    )
    @test _is_constraint_equal(
        expected_min,
        _get_cons_object(energy_problem.model, :min_storage_level_intra_rep_period_limit),
    )
end

@testitem "Storage bound modes create only required objects" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_storage_bounds_problem(;
        assets = [
            (;
                name = "rep_positive",
                use_inter_period_constraints = false,
                min_profile = fill(0.2, 4),
            ),
            (; name = "rep_zero", use_inter_period_constraints = false, min_profile = zeros(4)),
            (name = "rep_missing", use_inter_period_constraints = false),
            (;
                name = "inter_positive",
                use_inter_period_constraints = true,
                bounds = "inter_period_only",
                min_profile = fill(0.2, 4),
            ),
            (;
                name = "inter_zero",
                use_inter_period_constraints = true,
                bounds = "inter_period_only",
                min_profile = zeros(4),
            ),
            (;
                name = "conservative",
                use_inter_period_constraints = true,
                bounds = "inter_and_intra_rep_period",
                min_profile = zeros(4),
            ),
            (; name = "unbounded", use_inter_period_constraints = true, bounds = "none"),
        ],
    )
    connection = energy_problem.db_connection

    @test constraint_assets(connection, :max_storage_level_intra_rep_period_limit) ==
          Set(["rep_missing", "rep_positive", "rep_zero"])
    @test constraint_assets(connection, :min_storage_level_intra_rep_period_limit) ==
          Set(["rep_positive"])
    @test constraint_assets(connection, :max_storage_level_inter_period_limit) ==
          Set(["conservative", "inter_positive", "inter_zero"])
    @test constraint_assets(connection, :min_storage_level_inter_period_limit) ==
          Set(["conservative", "inter_positive"])

    increase = energy_problem.variables[:max_storage_level_increase_intra_rep_period]
    decrease = energy_problem.variables[:max_storage_level_decrease_intra_rep_period]
    @test length(increase.container) == 2
    @test length(decrease.container) == 2
    @test all(variable -> JuMP.lower_bound(variable) == 0.0, increase.container)
    @test all(variable -> JuMP.lower_bound(variable) == 0.0, decrease.container)
    @test length(energy_problem.model[:max_storage_level_increase_intra_rep_period_limit]) == 4
    @test length(energy_problem.model[:max_storage_level_decrease_intra_rep_period_limit]) == 4
    @test constraint_assets(connection, :balance_storage_inter_period) ==
          Set(["conservative", "inter_positive", "inter_zero", "unbounded"])
    @test constraint_assets(connection, :accumulated_storage_intra_period) ==
          Set(["conservative", "inter_positive", "inter_zero", "unbounded"])
end

@testitem "Inter-period-only storage bounds preserve equations 4a and 4b" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_storage_bounds_problem(;
        assets = [
            (;
                name = "simple_fixed",
                use_inter_period_constraints = true,
                bounds = "inter_period_only",
                max_profile = fill(0.8, 4),
                min_profile = fill(0.2, 4),
            ),
            (;
                name = "simple_optimized",
                use_inter_period_constraints = true,
                bounds = "inter_period_only",
                storage_method_energy = "optimize_storage_capacity",
                investable = true,
                max_profile = fill(0.7, 4),
                min_profile = fill(0.1, 4),
            ),
            (;
                name = "simple_ratio",
                use_inter_period_constraints = true,
                bounds = "inter_period_only",
                storage_method_energy = "use_fixed_energy_to_power_ratio",
                investable = true,
                max_profile = fill(0.9, 4),
                min_profile = fill(0.3, 4),
            ),
        ],
    )
    connection = energy_problem.db_connection
    capacity =
        energy_problem.expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]
    level = energy_problem.variables[:storage_level_inter_period].container

    max_rows = TEM._append_storage_level_inter_period_bound_data_to_indices(
        connection,
        :max_storage_level_inter_period_limit,
    )
    expected_max = [
        begin
            profile =
                Dict("simple_fixed" => 0.8, "simple_optimized" => 0.7, "simple_ratio" => 0.9)[row.asset]
            JuMP.@build_constraint(
                level[row.storage_level_id] <= profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in max_rows
    ]
    min_rows = TEM._append_storage_level_inter_period_bound_data_to_indices(
        connection,
        :min_storage_level_inter_period_limit,
    )
    expected_min = [
        begin
            profile =
                Dict("simple_fixed" => 0.2, "simple_optimized" => 0.1, "simple_ratio" => 0.3)[row.asset]
            JuMP.@build_constraint(
                level[row.storage_level_id] >= profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in min_rows
    ]

    @test _is_constraint_equal(
        expected_max,
        _get_cons_object(energy_problem.model, :max_storage_level_inter_period_limit),
    )
    @test _is_constraint_equal(
        expected_min,
        _get_cons_object(energy_problem.model, :min_storage_level_inter_period_limit),
    )
    @test isempty(energy_problem.variables[:max_storage_level_increase_intra_rep_period].container)
    @test isempty(energy_problem.model[:max_storage_level_increase_intra_rep_period_limit])
end

@testitem "Conservative storage bounds implement equations 6a to 6e" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_storage_bounds_problem(;
        assets = [
            (;
                name = "cyclic",
                use_inter_period_constraints = true,
                bounds = "inter_and_intra_rep_period",
                storage_loss = 0.1,
                max_profile = fill(0.8, 4),
                min_profile = zeros(4),
            ),
            (;
                name = "fixed_initial",
                use_inter_period_constraints = true,
                bounds = "inter_and_intra_rep_period",
                initial_storage_level = 0.25,
                storage_method_energy = "optimize_storage_capacity",
                investable = true,
                storage_loss = 0.1,
                max_profile = fill(0.7, 4),
                min_profile = fill(0.2, 4),
            ),
            (;
                name = "fixed_ratio",
                use_inter_period_constraints = true,
                bounds = "inter_and_intra_rep_period",
                storage_method_energy = "use_fixed_energy_to_power_ratio",
                investable = true,
                storage_loss = 0.1,
                max_profile = fill(0.6, 4),
                min_profile = fill(0.3, 4),
            ),
        ],
    )
    connection = energy_problem.db_connection
    accumulated = energy_problem.variables[:accumulated_storage_level_intra_rep_period].container
    increase = energy_problem.variables[:max_storage_level_increase_intra_rep_period].container
    decrease = energy_problem.variables[:max_storage_level_decrease_intra_rep_period].container

    rows = DuckDB.query(connection, "FROM cons_storage_level_intra_rep_period_bounds ORDER BY id")
    expected_increase = [
        JuMP.@build_constraint(
            accumulated[row.accumulated_storage_level_id] <=
            increase[row.max_storage_level_increase_id]
        ) for row in rows
    ]
    rows = DuckDB.query(connection, "FROM cons_storage_level_intra_rep_period_bounds ORDER BY id")
    expected_decrease = [
        JuMP.@build_constraint(
            -decrease[row.max_storage_level_decrease_id] <=
            accumulated[row.accumulated_storage_level_id]
        ) for row in rows
    ]
    @test _is_constraint_equal(
        expected_increase,
        _get_cons_object(energy_problem.model, :max_storage_level_increase_intra_rep_period_limit),
    )
    @test _is_constraint_equal(
        expected_decrease,
        _get_cons_object(energy_problem.model, :max_storage_level_decrease_intra_rep_period_limit),
    )

    capacity =
        energy_problem.expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]
    level = energy_problem.variables[:storage_level_inter_period].container
    max_cons = energy_problem.constraints[:max_storage_level_inter_period_limit]
    max_rows = TEM._append_storage_level_inter_period_bound_data_to_indices(
        connection,
        :max_storage_level_inter_period_limit,
    )
    expected_max = [
        begin
            initial_level = row.initial_storage_level::Union{Float64,Missing}
            previous_level = if row.period_block_start == 1 && !ismissing(initial_level)
                initial_level * capacity[row.avail_energy_capacity_id]
            elseif row.period_block_start > 1
                level[row.previous_id]
            else
                level[row.cycle_id]
            end
            profile =
                Dict("cyclic" => 0.8, "fixed_initial" => 0.7, "fixed_ratio" => 0.6)[row.asset]
            JuMP.@build_constraint(
                0.9 * previous_level +
                max_cons.expressions[:max_storage_level_increase_intra_rep_period][row.id] <=
                profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in max_rows
    ]

    min_cons = energy_problem.constraints[:min_storage_level_inter_period_limit]
    min_rows = TEM._append_storage_level_inter_period_bound_data_to_indices(
        connection,
        :min_storage_level_inter_period_limit,
    )
    expected_min = [
        begin
            initial_level = row.initial_storage_level::Union{Float64,Missing}
            previous_level = if row.period_block_start == 1 && !ismissing(initial_level)
                initial_level * capacity[row.avail_energy_capacity_id]
            elseif row.period_block_start > 1
                level[row.previous_id]
            else
                level[row.cycle_id]
            end
            profile =
                Dict("cyclic" => 0.0, "fixed_initial" => 0.2, "fixed_ratio" => 0.3)[row.asset]
            loss = 0.9^Int(row.duration_period_block)
            JuMP.@build_constraint(
                loss * previous_level -
                min_cons.expressions[:max_storage_level_decrease_intra_rep_period][row.id] >=
                profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in min_rows
    ]
    @test _is_constraint_equal(
        expected_max,
        _get_cons_object(energy_problem.model, :max_storage_level_inter_period_limit),
    )
    @test _is_constraint_equal(
        expected_min,
        _get_cons_object(energy_problem.model, :min_storage_level_inter_period_limit),
    )
end

@testitem "Conservative bounds aggregate multi-period timeframe blocks" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_storage_bounds_problem(;
        assets = [(;
            name = "block_storage",
            use_inter_period_constraints = true,
            bounds = "inter_and_intra_rep_period",
            timeframe_partition = 2,
            inflows_profile = collect(0.1:0.1:0.8),
            max_profile = [0.9, 0.8, 0.7, 0.6, 0.8, 0.7, 0.6, 0.5],
            min_profile = [0.1, 0.2, 0.3, 0.4, 0.2, 0.3, 0.4, 0.5],
            storage_loss = 0.1,
        ),],
        num_timesteps = 2,
        num_rep_periods = 2,
    )
    connection = energy_problem.db_connection
    capacity =
        energy_problem.expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]
    level = energy_problem.variables[:storage_level_inter_period].container

    max_cons = energy_problem.constraints[:max_storage_level_inter_period_limit]
    max_rows = collect(
        TEM._append_storage_level_inter_period_bound_data_to_indices(
            connection,
            :max_storage_level_inter_period_limit,
        ),
    )
    @test [(row.period_block_start, row.period_block_end) for row in max_rows] == [(1, 2), (3, 4)]
    @test all(row -> Int(row.duration_period_block) == 4, max_rows)
    @test all(
        expression -> sum(first, JuMP.linear_terms(expression)) == 2.0,
        max_cons.expressions[:max_storage_level_increase_intra_rep_period],
    )
    expected_max = [
        begin
            previous = row.period_block_start == 1 ? level[row.cycle_id] : level[row.previous_id]
            profile = TEM._profile_aggregate(
                energy_problem.profiles.inter_period,
                (row.max_storage_level_profile_name, row.milestone_year, row.scenario),
                row.period_block_start:row.period_block_end,
                minimum,
                1.0,
            )
            JuMP.@build_constraint(
                0.9 * previous +
                max_cons.expressions[:max_storage_level_increase_intra_rep_period][row.id] <=
                profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in max_rows
    ]

    min_cons = energy_problem.constraints[:min_storage_level_inter_period_limit]
    min_rows = collect(
        TEM._append_storage_level_inter_period_bound_data_to_indices(
            connection,
            :min_storage_level_inter_period_limit,
        ),
    )
    @test all(
        expression -> sum(first, JuMP.linear_terms(expression)) == 2.0,
        min_cons.expressions[:max_storage_level_decrease_intra_rep_period],
    )
    expected_min = [
        begin
            previous = row.period_block_start == 1 ? level[row.cycle_id] : level[row.previous_id]
            profile = TEM._profile_aggregate(
                energy_problem.profiles.inter_period,
                (row.min_storage_level_profile_name, row.milestone_year, row.scenario),
                row.period_block_start:row.period_block_end,
                maximum,
                0.0,
            )
            JuMP.@build_constraint(
                0.9^Int(row.duration_period_block) * previous -
                min_cons.expressions[:max_storage_level_decrease_intra_rep_period][row.id] >=
                profile * capacity[row.avail_energy_capacity_id]
            )
        end for row in min_rows
    ]

    @test _is_constraint_equal(
        expected_max,
        _get_cons_object(energy_problem.model, :max_storage_level_inter_period_limit),
    )
    @test _is_constraint_equal(
        expected_min,
        _get_cons_object(energy_problem.model, :min_storage_level_inter_period_limit),
    )
end
