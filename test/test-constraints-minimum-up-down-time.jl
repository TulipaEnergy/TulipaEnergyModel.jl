using JuMP

@testsnippet ConsMinUpDownTimeSetup begin
    function minimum_up_down_time_constraint_tests_common_setup!(connection, model, resolution)
        table_name = "asset"

        table_rows = [
            ("input_1", "aggregated", "3var", "conversion", 15, 4, 4),
            ("input_2", "compact_profiles", "3var", "conversion", 15, 4, 4),
            ("death_star", "aggregated", "3var", "conversion", 15, 4, 4),
        ]

        columns = [
            :asset,
            :vintage_method,
            :unit_commitment,
            :type,
            :technical_lifetime,
            :minimum_up_time,
            :minimum_down_time,
        ]

        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "rep_periods_data"
        table_rows = [(2050, 1, 9, resolution)]
        columns = [:milestone_year, :rep_period, :num_timesteps, :resolution]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "var_units_on"
        table_rows = [
            (1, "input_1", 2050, 1, 1, 1, true),
            (2, "input_1", 2050, 1, 2, 2, true),
            (3, "input_1", 2050, 1, 3, 3, true),
            (4, "input_1", 2050, 1, 4, 4, true),
            (5, "input_1", 2050, 1, 5, 5, true),
            (6, "input_1", 2050, 1, 6, 6, true),
            (7, "input_1", 2050, 1, 7, 7, true),
            (8, "input_1", 2050, 1, 8, 8, true),
            (9, "input_1", 2050, 1, 9, 9, true),
            (10, "input_2", 2050, 1, 1, 1, true),
            (11, "input_2", 2050, 1, 2, 2, true),
            (12, "input_2", 2050, 1, 3, 3, true),
            (13, "input_2", 2050, 1, 4, 4, true),
            (14, "input_2", 2050, 1, 5, 5, true),
            (15, "input_2", 2050, 1, 6, 6, true),
            (16, "input_2", 2050, 1, 7, 7, true),
            (17, "input_2", 2050, 1, 8, 8, true),
            (18, "input_2", 2050, 1, 9, 9, true),
            (19, "death_star", 2050, 1, 1, 1, true),
            (20, "death_star", 2050, 1, 2, 2, true),
            (21, "death_star", 2050, 1, 3, 3, true),
            (22, "death_star", 2050, 1, 4, 4, true),
            (23, "death_star", 2050, 1, 5, 5, true),
            (24, "death_star", 2050, 1, 6, 6, true),
            (25, "death_star", 2050, 1, 7, 7, true),
            (26, "death_star", 2050, 1, 8, 8, true),
            (27, "death_star", 2050, 1, 9, 9, true),
        ]

        columns = [
            :id,
            :asset,
            :milestone_year,
            :rep_period,
            :time_block_start,
            :time_block_end,
            :unit_commitment_integer,
        ]

        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "var_start_up"
        table_rows = [
            (1, "input_1", 2050, 1, 1, 1, true),
            (2, "input_1", 2050, 1, 2, 2, true),
            (3, "input_1", 2050, 1, 3, 3, true),
            (4, "input_1", 2050, 1, 4, 4, true),
            (5, "input_1", 2050, 1, 5, 5, true),
            (6, "input_1", 2050, 1, 6, 6, true),
            (7, "input_1", 2050, 1, 7, 7, true),
            (8, "input_1", 2050, 1, 8, 8, true),
            (9, "input_1", 2050, 1, 9, 9, true),
            (10, "input_2", 2050, 1, 1, 1, true),
            (11, "input_2", 2050, 1, 2, 2, true),
            (12, "input_2", 2050, 1, 3, 3, true),
            (13, "input_2", 2050, 1, 4, 4, true),
            (14, "input_2", 2050, 1, 5, 5, true),
            (15, "input_2", 2050, 1, 6, 6, true),
            (16, "input_2", 2050, 1, 7, 7, true),
            (17, "input_2", 2050, 1, 8, 8, true),
            (18, "input_2", 2050, 1, 9, 9, true),
            (19, "death_star", 2050, 1, 1, 1, true),
            (20, "death_star", 2050, 1, 2, 2, true),
            (21, "death_star", 2050, 1, 3, 3, true),
            (22, "death_star", 2050, 1, 4, 4, true),
            (23, "death_star", 2050, 1, 5, 5, true),
            (24, "death_star", 2050, 1, 6, 6, true),
            (25, "death_star", 2050, 1, 7, 7, true),
            (26, "death_star", 2050, 1, 8, 8, true),
            (27, "death_star", 2050, 1, 9, 9, true),
        ]

        columns = [
            :id,
            :asset,
            :milestone_year,
            :rep_period,
            :time_block_start,
            :time_block_end,
            :unit_commitment_integer,
        ]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "var_shut_down"
        table_rows = [
            (1, "input_1", 2050, 1, 1, 1, true),
            (2, "input_1", 2050, 1, 2, 2, true),
            (3, "input_1", 2050, 1, 3, 3, true),
            (4, "input_1", 2050, 1, 4, 4, true),
            (5, "input_1", 2050, 1, 5, 5, true),
            (6, "input_1", 2050, 1, 6, 6, true),
            (7, "input_1", 2050, 1, 7, 7, true),
            (8, "input_1", 2050, 1, 8, 8, true),
            (9, "input_1", 2050, 1, 9, 9, true),
            (10, "input_2", 2050, 1, 1, 1, true),
            (11, "input_2", 2050, 1, 2, 2, true),
            (12, "input_2", 2050, 1, 3, 3, true),
            (13, "input_2", 2050, 1, 4, 4, true),
            (14, "input_2", 2050, 1, 5, 5, true),
            (15, "input_2", 2050, 1, 6, 6, true),
            (16, "input_2", 2050, 1, 7, 7, true),
            (17, "input_2", 2050, 1, 8, 8, true),
            (18, "input_2", 2050, 1, 9, 9, true),
            (19, "death_star", 2050, 1, 1, 1, true),
            (20, "death_star", 2050, 1, 2, 2, true),
            (21, "death_star", 2050, 1, 3, 3, true),
            (22, "death_star", 2050, 1, 4, 4, true),
            (23, "death_star", 2050, 1, 5, 5, true),
            (24, "death_star", 2050, 1, 6, 6, true),
            (25, "death_star", 2050, 1, 7, 7, true),
            (26, "death_star", 2050, 1, 8, 8, true),
            (27, "death_star", 2050, 1, 9, 9, true),
        ]

        columns = [
            :id,
            :asset,
            :milestone_year,
            :rep_period,
            :time_block_start,
            :time_block_end,
            :unit_commitment_integer,
        ]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
            key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
            key in (:units_on, :start_up, :shut_down)
        )
        TulipaEnergyModel.add_unit_commitment_variables!(model, variables)
        TulipaEnergyModel.add_start_up_and_shut_down_variables!(model, variables)

        table_name = "cons_minimum_down_time_aggregated_vintage_method"
        table_rows = [
            (1, "input_1", 2050, 1, 1, 1),
            (2, "input_1", 2050, 1, 2, 2),
            (3, "input_1", 2050, 1, 3, 3),
            (4, "input_1", 2050, 1, 4, 4),
            (5, "input_1", 2050, 1, 5, 5),
            (6, "input_1", 2050, 1, 6, 6),
            (7, "input_1", 2050, 1, 7, 7),
            (8, "input_1", 2050, 1, 8, 8),
            (9, "input_1", 2050, 1, 9, 9),
            (10, "death_star", 2050, 1, 1, 1),
            (11, "death_star", 2050, 1, 2, 2),
            (12, "death_star", 2050, 1, 3, 3),
            (13, "death_star", 2050, 1, 4, 4),
            (14, "death_star", 2050, 1, 5, 5),
            (15, "death_star", 2050, 1, 6, 6),
            (16, "death_star", 2050, 1, 7, 7),
            (17, "death_star", 2050, 1, 8, 8),
            (18, "death_star", 2050, 1, 9, 9),
        ]
        columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "cons_minimum_down_time_compact_vintage_method"
        table_rows = [
            (1, "input_2", 2050, 1, 1, 1),
            (2, "input_2", 2050, 1, 2, 2),
            (3, "input_2", 2050, 1, 3, 3),
            (4, "input_2", 2050, 1, 4, 4),
            (5, "input_2", 2050, 1, 5, 5),
            (6, "input_2", 2050, 1, 6, 6),
            (7, "input_2", 2050, 1, 7, 7),
            (8, "input_2", 2050, 1, 8, 8),
            (9, "input_2", 2050, 1, 9, 9),
        ]
        columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "cons_minimum_up_time"
        table_rows = [
            (1, "input_1", 2050, 1, 1, 1),
            (2, "input_1", 2050, 1, 2, 2),
            (3, "input_1", 2050, 1, 3, 3),
            (4, "input_1", 2050, 1, 4, 4),
            (5, "input_1", 2050, 1, 5, 5),
            (6, "input_1", 2050, 1, 6, 6),
            (7, "input_1", 2050, 1, 7, 7),
            (8, "input_1", 2050, 1, 8, 8),
            (9, "input_1", 2050, 1, 9, 9),
            (10, "input_2", 2050, 1, 1, 1),
            (11, "input_2", 2050, 1, 2, 2),
            (12, "input_2", 2050, 1, 3, 3),
            (13, "input_2", 2050, 1, 4, 4),
            (14, "input_2", 2050, 1, 5, 5),
            (15, "input_2", 2050, 1, 6, 6),
            (16, "input_2", 2050, 1, 7, 7),
            (17, "input_2", 2050, 1, 8, 8),
            (18, "input_2", 2050, 1, 9, 9),
            (19, "death_star", 2050, 1, 1, 1),
            (20, "death_star", 2050, 1, 2, 2),
            (21, "death_star", 2050, 1, 3, 3),
            (22, "death_star", 2050, 1, 4, 4),
            (23, "death_star", 2050, 1, 5, 5),
            (24, "death_star", 2050, 1, 6, 6),
            (25, "death_star", 2050, 1, 7, 7),
            (26, "death_star", 2050, 1, 8, 8),
            (27, "death_star", 2050, 1, 9, 9),
        ]
        columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
            key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for key in (
                :minimum_up_time,
                :minimum_down_time_aggregated_vintage_method,
                :minimum_down_time_compact_vintage_method,
            )
        )

        table_name = "expr_available_asset_units_aggregated_vintage_method"
        table_rows = [(1, "input_1", 2050, 2050, 1, 1, 1), (2, "death_star", 2050, 2050, 1, 2, 2)]
        columns = [
            :id,
            :asset,
            :milestone_year,
            :commission_year,
            :initial_units,
            :var_investment_indices,
            :var_decommission_indices,
        ]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        table_name = "expr_available_asset_units_compact_vintage_method"
        table_rows = [(1, "input_2", 2050, 2050, 1, 3, 3)]
        columns = [
            :id,
            :asset,
            :milestone_year,
            :commission_year,
            :initial_units,
            :var_investment_indices,
            :var_decommission_indices,
        ]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        expressions = Dict{Symbol,TulipaEnergyModel.TulipaExpression}(
            key => TulipaEnergyModel.TulipaExpression(connection, "expr_$key") for key in (
                :available_asset_units_aggregated_vintage_method,
                :available_asset_units_compact_vintage_method,
            )
        )

        expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets] = [
            JuMP.@expression(model, 1),
            JuMP.@expression(model, 1),
            JuMP.@expression(model, 1),
            JuMP.@expression(model, 1)
        ]

        expressions[:available_asset_units_compact_vintage_method].expressions[:assets] =
            [JuMP.@expression(model, 1), JuMP.@expression(model, 1)]

        TulipaEnergyModel.add_minimum_up_time_constraints!(
            connection,
            model,
            variables,
            expressions,
            constraints,
        )

        TulipaEnergyModel.add_minimum_down_time_constraints!(
            connection,
            model,
            variables,
            expressions,
            constraints,
        )

        return variables, constraints, expressions
    end
end

@testitem "Test minimum up/down time constraints" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset table
    table_name = "asset"
    table_rows = [
        ("input_1", "aggregated", "3var", "conversion", 15, 4, 4),
        ("input_2", "compact_profiles", "3var", "conversion", 15, 4, 4),
        ("death_star", "aggregated", "3var", "conversion", 15, 4, 4),
    ]
    columns = [
        :asset,
        :vintage_method,
        :unit_commitment,
        :type,
        :technical_lifetime,
        :minimum_up_time,
        :minimum_down_time,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "rep_periods_data"
    table_rows = [(2050, 1, 9, 1.0)]
    columns = [:milestone_year, :rep_period, :num_timesteps, :resolution]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_units_on"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 3, true),
        (2, "input_1", 2050, 1, 4, 7, true),
        (3, "input_2", 2050, 1, 1, 3, true),
        (4, "input_2", 2050, 1, 4, 7, true),
        (5, "death_star", 2050, 1, 1, 3, true),
        (6, "death_star", 2050, 1, 4, 7, true),
    ]

    columns = [
        :id,
        :asset,
        :milestone_year,
        :rep_period,
        :time_block_start,
        :time_block_end,
        :unit_commitment_integer,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_start_up"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2, true),
        (2, "input_1", 2050, 1, 4, 4, true),
        (3, "input_2", 2050, 1, 1, 2, true),
        (4, "input_2", 2050, 1, 4, 4, true),
        (5, "death_star", 2050, 1, 1, 2, true),
        (6, "death_star", 2050, 1, 4, 4, true),
    ]

    columns = [
        :id,
        :asset,
        :milestone_year,
        :rep_period,
        :time_block_start,
        :time_block_end,
        :unit_commitment_integer,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_shut_down"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2, true),
        (2, "input_1", 2050, 1, 4, 4, true),
        (3, "input_2", 2050, 1, 1, 2, true),
        (4, "input_2", 2050, 1, 4, 4, true),
        (5, "death_star", 2050, 1, 1, 2, true),
        (6, "death_star", 2050, 1, 4, 4, true),
    ]

    columns = [
        :id,
        :asset,
        :milestone_year,
        :rep_period,
        :time_block_start,
        :time_block_end,
        :unit_commitment_integer,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:units_on, :start_up, :shut_down)
    )
    TulipaEnergyModel.add_unit_commitment_variables!(model, variables)
    TulipaEnergyModel.add_start_up_and_shut_down_variables!(model, variables)

    table_name = "cons_minimum_down_time_aggregated_vintage_method"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2),
        (2, "input_1", 2050, 1, 4, 4),
        (3, "death_star", 2050, 1, 1, 2),
        (4, "death_star", 2050, 1, 4, 4),
    ]
    columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_minimum_down_time_compact_vintage_method"
    table_rows = [(1, "input_2", 2050, 1, 1, 2), (2, "input_2", 2050, 1, 4, 4)]
    columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_minimum_up_time"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2),
        (2, "input_1", 2050, 1, 4, 4),
        (3, "input_2", 2050, 1, 1, 2),
        (4, "input_2", 2050, 1, 4, 4),
        (5, "death_star", 2050, 1, 1, 2),
        (6, "death_star", 2050, 1, 4, 4),
    ]
    columns = [:id, :asset, :milestone_year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for key in (
            :minimum_up_time,
            :minimum_down_time_aggregated_vintage_method,
            :minimum_down_time_compact_vintage_method,
        )
    )

    table_name = "expr_available_asset_units_aggregated_vintage_method"
    table_rows = [(1, "input_1", 2050, 2050, 1, 1, 1), (2, "death_star", 2050, 2050, 1, 2, 2)]
    columns = [
        :id,
        :asset,
        :milestone_year,
        :commission_year,
        :initial_units,
        :var_investment_indices,
        :var_decommission_indices,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "expr_available_asset_units_compact_vintage_method"
    table_rows = [(1, "input_2", 2050, 2050, 1, 3, 3)]
    columns = [
        :id,
        :asset,
        :milestone_year,
        :commission_year,
        :initial_units,
        :var_investment_indices,
        :var_decommission_indices,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    expressions = Dict{Symbol,TulipaEnergyModel.TulipaExpression}(
        key => TulipaEnergyModel.TulipaExpression(connection, "expr_$key") for key in (
            :available_asset_units_aggregated_vintage_method,
            :available_asset_units_compact_vintage_method,
        )
    )

    expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets] = [
        JuMP.@expression(model, 1),
        JuMP.@expression(model, 1),
        JuMP.@expression(model, 1),
        JuMP.@expression(model, 1)
    ]

    expressions[:available_asset_units_compact_vintage_method].expressions[:assets] =
        [JuMP.@expression(model, 1), JuMP.@expression(model, 1)]

    TulipaEnergyModel.add_minimum_up_time_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    TulipaEnergyModel.add_minimum_down_time_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    # Test the constraints
    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(var_start_up[3] <= var_units_on[3]),
        JuMP.@build_constraint(var_start_up[3] + var_start_up[4] <= var_units_on[4]),
        JuMP.@build_constraint(var_start_up[5] <= var_units_on[5]),
        JuMP.@build_constraint(var_start_up[5] + var_start_up[6] <= var_units_on[6])
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(var_shut_down[5] <= 1 - var_units_on[5]),
        JuMP.@build_constraint(var_shut_down[5] + var_shut_down[6] <= 1 - var_units_on[6]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[3] <= 1 - var_units_on[3]),
        JuMP.@build_constraint(var_shut_down[3] + var_shut_down[4] <= 1 - var_units_on[4]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testitem "Test minimum up/down time constraints with resolution 2.0" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    variables, constraints, expressions =
        minimum_up_down_time_constraint_tests_common_setup!(connection, model, 2.0)

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(var_start_up[2] + var_start_up[3] <= var_units_on[3]),
        JuMP.@build_constraint(var_start_up[3] + var_start_up[4] <= var_units_on[4]),
        JuMP.@build_constraint(var_start_up[4] + var_start_up[5] <= var_units_on[5]),
        JuMP.@build_constraint(var_start_up[5] + var_start_up[6] <= var_units_on[6]),
        JuMP.@build_constraint(var_start_up[6] + var_start_up[7] <= var_units_on[7]),
        JuMP.@build_constraint(var_start_up[7] + var_start_up[8] <= var_units_on[8]),
        JuMP.@build_constraint(var_start_up[8] + var_start_up[9] <= var_units_on[9]),
        JuMP.@build_constraint(var_start_up[10] <= var_units_on[10]),
        JuMP.@build_constraint(var_start_up[10] + var_start_up[11] <= var_units_on[11]),
        JuMP.@build_constraint(var_start_up[11] + var_start_up[12] <= var_units_on[12]),
        JuMP.@build_constraint(var_start_up[12] + var_start_up[13] <= var_units_on[13]),
        JuMP.@build_constraint(var_start_up[13] + var_start_up[14] <= var_units_on[14]),
        JuMP.@build_constraint(var_start_up[14] + var_start_up[15] <= var_units_on[15]),
        JuMP.@build_constraint(var_start_up[15] + var_start_up[16] <= var_units_on[16]),
        JuMP.@build_constraint(var_start_up[16] + var_start_up[17] <= var_units_on[17]),
        JuMP.@build_constraint(var_start_up[17] + var_start_up[18] <= var_units_on[18]),
        JuMP.@build_constraint(var_start_up[19] <= var_units_on[19]),
        JuMP.@build_constraint(var_start_up[19] + var_start_up[20] <= var_units_on[20]),
        JuMP.@build_constraint(var_start_up[20] + var_start_up[21] <= var_units_on[21]),
        JuMP.@build_constraint(var_start_up[21] + var_start_up[22] <= var_units_on[22]),
        JuMP.@build_constraint(var_start_up[22] + var_start_up[23] <= var_units_on[23]),
        JuMP.@build_constraint(var_start_up[23] + var_start_up[24] <= var_units_on[24]),
        JuMP.@build_constraint(var_start_up[24] + var_start_up[25] <= var_units_on[25]),
        JuMP.@build_constraint(var_start_up[25] + var_start_up[26] <= var_units_on[26]),
        JuMP.@build_constraint(var_start_up[26] + var_start_up[27] <= var_units_on[27]),
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(var_shut_down[2] + var_shut_down[3] <= 1 - var_units_on[3]),
        JuMP.@build_constraint(var_shut_down[3] + var_shut_down[4] <= 1 - var_units_on[4]),
        JuMP.@build_constraint(var_shut_down[4] + var_shut_down[5] <= 1 - var_units_on[5]),
        JuMP.@build_constraint(var_shut_down[5] + var_shut_down[6] <= 1 - var_units_on[6]),
        JuMP.@build_constraint(var_shut_down[6] + var_shut_down[7] <= 1 - var_units_on[7]),
        JuMP.@build_constraint(var_shut_down[7] + var_shut_down[8] <= 1 - var_units_on[8]),
        JuMP.@build_constraint(var_shut_down[8] + var_shut_down[9] <= 1 - var_units_on[9]),
        JuMP.@build_constraint(var_shut_down[19] <= 1 - var_units_on[19]),
        JuMP.@build_constraint(var_shut_down[19] + var_shut_down[20] <= 1 - var_units_on[20]),
        JuMP.@build_constraint(var_shut_down[20] + var_shut_down[21] <= 1 - var_units_on[21]),
        JuMP.@build_constraint(var_shut_down[21] + var_shut_down[22] <= 1 - var_units_on[22]),
        JuMP.@build_constraint(var_shut_down[22] + var_shut_down[23] <= 1 - var_units_on[23]),
        JuMP.@build_constraint(var_shut_down[23] + var_shut_down[24] <= 1 - var_units_on[24]),
        JuMP.@build_constraint(var_shut_down[24] + var_shut_down[25] <= 1 - var_units_on[25]),
        JuMP.@build_constraint(var_shut_down[25] + var_shut_down[26] <= 1 - var_units_on[26]),
        JuMP.@build_constraint(var_shut_down[26] + var_shut_down[27] <= 1 - var_units_on[27]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[10] <= 1 - var_units_on[10]),
        JuMP.@build_constraint(var_shut_down[10] + var_shut_down[11] <= 1 - var_units_on[11]),
        JuMP.@build_constraint(var_shut_down[11] + var_shut_down[12] <= 1 - var_units_on[12]),
        JuMP.@build_constraint(var_shut_down[12] + var_shut_down[13] <= 1 - var_units_on[13]),
        JuMP.@build_constraint(var_shut_down[13] + var_shut_down[14] <= 1 - var_units_on[14]),
        JuMP.@build_constraint(var_shut_down[14] + var_shut_down[15] <= 1 - var_units_on[15]),
        JuMP.@build_constraint(var_shut_down[15] + var_shut_down[16] <= 1 - var_units_on[16]),
        JuMP.@build_constraint(var_shut_down[16] + var_shut_down[17] <= 1 - var_units_on[17]),
        JuMP.@build_constraint(var_shut_down[17] + var_shut_down[18] <= 1 - var_units_on[18]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testitem "Test minimum up/down time constraints with resolution 0.5" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    variables, constraints, expressions =
        minimum_up_down_time_constraint_tests_common_setup!(connection, model, 0.5)

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(
            var_start_up[1] + var_start_up[2] + var_start_up[3] <= var_units_on[3]
        ),
        JuMP.@build_constraint(
            var_start_up[1] + var_start_up[2] + var_start_up[3] + var_start_up[4] <=
            var_units_on[4]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] <= var_units_on[5]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] <= var_units_on[6]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] <= var_units_on[7]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] +
            var_start_up[8] <= var_units_on[8]
        ),
        JuMP.@build_constraint(
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] +
            var_start_up[8] +
            var_start_up[9] <= var_units_on[9]
        ),
        JuMP.@build_constraint(var_start_up[10] <= var_units_on[10]),
        JuMP.@build_constraint(var_start_up[10] + var_start_up[11] <= var_units_on[11]),
        JuMP.@build_constraint(
            var_start_up[10] + var_start_up[11] + var_start_up[12] <= var_units_on[12]
        ),
        JuMP.@build_constraint(
            var_start_up[10] + var_start_up[11] + var_start_up[12] + var_start_up[13] <=
            var_units_on[13]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] <= var_units_on[14]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] <= var_units_on[15]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] <= var_units_on[16]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] +
            var_start_up[17] <= var_units_on[17]
        ),
        JuMP.@build_constraint(
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] +
            var_start_up[17] +
            var_start_up[18] <= var_units_on[18]
        ),
        JuMP.@build_constraint(var_start_up[19] <= var_units_on[19]),
        JuMP.@build_constraint(var_start_up[19] + var_start_up[20] <= var_units_on[20]),
        JuMP.@build_constraint(
            var_start_up[19] + var_start_up[20] + var_start_up[21] <= var_units_on[21]
        ),
        JuMP.@build_constraint(
            var_start_up[19] + var_start_up[20] + var_start_up[21] + var_start_up[22] <=
            var_units_on[22]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] <= var_units_on[23]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] <= var_units_on[24]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] <= var_units_on[25]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] +
            var_start_up[26] <= var_units_on[26]
        ),
        JuMP.@build_constraint(
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] +
            var_start_up[26] +
            var_start_up[27] <= var_units_on[27]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(
            var_shut_down[1] + var_shut_down[2] + var_shut_down[3] <= 1 - var_units_on[3]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] + var_shut_down[2] + var_shut_down[3] + var_shut_down[4] <=
            1 - var_units_on[4]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] <= 1 - var_units_on[5]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] <= 1 - var_units_on[6]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] <= 1 - var_units_on[7]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] +
            var_shut_down[8] <= 1 - var_units_on[8]
        ),
        JuMP.@build_constraint(
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] +
            var_shut_down[8] +
            var_shut_down[9] <= 1 - var_units_on[9]
        ),
        JuMP.@build_constraint(var_shut_down[19] <= 1 - var_units_on[19]),
        JuMP.@build_constraint(var_shut_down[19] + var_shut_down[20] <= 1 - var_units_on[20]),
        JuMP.@build_constraint(
            var_shut_down[19] + var_shut_down[20] + var_shut_down[21] <= 1 - var_units_on[21]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] + var_shut_down[20] + var_shut_down[21] + var_shut_down[22] <=
            1 - var_units_on[22]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] <= 1 - var_units_on[23]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] <= 1 - var_units_on[24]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] <= 1 - var_units_on[25]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] +
            var_shut_down[26] <= 1 - var_units_on[26]
        ),
        JuMP.@build_constraint(
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] +
            var_shut_down[26] +
            var_shut_down[27] <= 1 - var_units_on[27]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[10] <= 1 - var_units_on[10]),
        JuMP.@build_constraint(var_shut_down[10] + var_shut_down[11] <= 1 - var_units_on[11]),
        JuMP.@build_constraint(
            var_shut_down[10] + var_shut_down[11] + var_shut_down[12] <= 1 - var_units_on[12]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] + var_shut_down[11] + var_shut_down[12] + var_shut_down[13] <=
            1 - var_units_on[13]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] <= 1 - var_units_on[14]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] <= 1 - var_units_on[15]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] <= 1 - var_units_on[16]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] +
            var_shut_down[17] <= 1 - var_units_on[17]
        ),
        JuMP.@build_constraint(
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] +
            var_shut_down[17] +
            var_shut_down[18] <= 1 - var_units_on[18]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)
end
