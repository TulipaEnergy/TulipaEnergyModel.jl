using JuMP

@testset "Test tight SUSD constraints" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset table
    table_name = "asset"
    table_rows = [
        ("input_1", "simple", true, "3bin-0", "conversion", 15),
        ("input_2", "compact", true, "3bin-0", "conversion", 15),
        ("death_star", "simple", true, "3bin-0", "conversion", 15),
    ]
    columns = [
        :asset,
        :investment_method,
        :unit_commitment,
        :unit_commitment_method,
        :type,
        :technical_lifetime,
    ]
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
        :year,
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
        :year,
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
        :year,
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

    table_name = "cons_start_up_upper_bound"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2),
        (2, "input_1", 2050, 1, 4, 4),
        (3, "input_2", 2050, 1, 1, 2),
        (4, "input_2", 2050, 1, 4, 4),
        (5, "death_star", 2050, 1, 1, 2),
        (6, "death_star", 2050, 1, 4, 4),
    ]
    columns = [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_shut_down_upper_bound_simple_investment"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2),
        (2, "input_1", 2050, 1, 4, 4),
        (5, "death_star", 2050, 1, 1, 2),
        (6, "death_star", 2050, 1, 4, 4),
    ]
    columns = [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_shut_down_upper_bound_compact_investment"
    table_rows = [(3, "input_2", 2050, 1, 1, 2), (4, "input_2", 2050, 1, 4, 4)]
    columns = [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_su_sd_eq_units_on_diff"
    table_rows = [
        (1, "input_1", 2050, 1, 1, 2),
        (2, "input_1", 2050, 1, 4, 4),
        (3, "input_2", 2050, 1, 1, 2),
        (4, "input_2", 2050, 1, 4, 4),
        (5, "death_star", 2050, 1, 1, 2),
        (6, "death_star", 2050, 1, 4, 4),
    ]
    columns = [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for key in (
            :start_up_upper_bound,
            :shut_down_upper_bound_simple_investment,
            :shut_down_upper_bound_compact_investment,
            :su_sd_eq_units_on_diff,
        )
    )

    table_name = "expr_available_asset_units_simple_method"
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

    table_name = "expr_available_asset_units_compact_method"
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
        key => TulipaEnergyModel.TulipaExpression(connection, "expr_$key") for
        key in (:available_asset_units_simple_method, :available_asset_units_compact_method)
    )

    expressions[:available_asset_units_simple_method].expressions[:assets] =
        [@expression(model, 1), @expression(model, 1), @expression(model, 1), @expression(model, 1)]

    expressions[:available_asset_units_compact_method].expressions[:assets] =
        [@expression(model, 1), @expression(model, 1)]

    TulipaEnergyModel.add_start_up_upper_bound_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    TulipaEnergyModel.add_shut_down_upper_bound_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    TulipaEnergyModel.add_su_sd_eq_units_on_diff_constraints!(
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
        JuMP.@build_constraint(var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(var_start_up[3] <= var_units_on[3]),
        JuMP.@build_constraint(var_start_up[4] <= var_units_on[4]),
        JuMP.@build_constraint(var_start_up[5] <= var_units_on[5]),
        JuMP.@build_constraint(var_start_up[6] <= var_units_on[6])
    ]
    observed_cons = _get_cons_object(model, :start_up_upper_bound)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(var_shut_down[5] <= 1 - var_units_on[5]),
        JuMP.@build_constraint(var_shut_down[6] <= 1 - var_units_on[6]),
    ]
    observed_cons = _get_cons_object(model, :shut_down_upper_bound_simple_investment)
    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[3] <= 1 - var_units_on[3]),
        JuMP.@build_constraint(var_shut_down[4] <= 1 - var_units_on[4]),
    ]
    observed_cons = _get_cons_object(model, :shut_down_upper_bound_compact_investment)
    @test _is_constraint_equal(expected_cons, observed_cons)

    @variable(model, dummy)

    expected_cons = [
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(
            var_units_on[2] - var_units_on[1] == var_start_up[2] - var_shut_down[2]
        ),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(
            var_units_on[4] - var_units_on[3] == var_start_up[4] - var_shut_down[4]
        ),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(
            var_units_on[6] - var_units_on[5] == var_start_up[6] - var_shut_down[6]
        ),
    ]

    observed_cons = _get_cons_object(model, :su_sd_eq_units_on_diff)

    @test _is_constraint_equal(expected_cons, observed_cons)
end
