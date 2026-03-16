using JuMP

@testitem "Test compact SUSD constraints" setup = [CommonSetup] tags = [:unit, :validation, :fast] begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    table_name = "asset"
    table_rows = [
        ("input_1", "simple", true, "SU-SD-compact", "conversion", 15),
        ("input_2", "compact", true, "SU-SD-compact", "conversion", 15),
        ("death_star", "simple", true, "SU-SD-compact", "conversion", 15),
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

    table_name = "cons_start_up_lower_bound"
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

    table_name = "cons_shut_down_lower_bound"
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
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for
        key in (:start_up_lower_bound, :shut_down_lower_bound)
    )

    expressions = Dict{Symbol,TulipaEnergyModel.TulipaExpression}()

    TulipaEnergyModel.add_start_up_lower_bound_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    TulipaEnergyModel.add_shut_down_lower_bound_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

    JuMP.@variable(model, dummy)

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    # test start-up lower bound constraint
    expected_cons = [
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[2] - var_units_on[1] <= var_start_up[2]),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[4] - var_units_on[3] <= var_start_up[4]),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[6] - var_units_on[5] <= var_start_up[6]),
    ]
    observed_cons = _get_cons_object(model, :start_up_lower_bound)
    @test _is_constraint_equal(expected_cons, observed_cons)

    # test shut-down lower bound constraint
    expected_cons = [
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[1] - var_units_on[2] <= var_shut_down[2]),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[3] - var_units_on[4] <= var_shut_down[4]),
        JuMP.@build_constraint(0 * dummy == 0),
        JuMP.@build_constraint(var_units_on[5] - var_units_on[6] <= var_shut_down[6]),
    ]
    observed_cons = _get_cons_object(model, :shut_down_lower_bound)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
