@testset "Test add_vintage_flow_sum_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset table
    table_name = "asset"
    table_rows = [("input_1", "semi-compact"), ("input_2", "compact"), ("death_star", "simple")]
    columns = [:asset, :investment_method]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "flow"
    table_rows = [
        ("input_1", "death_star", false),
        ("input_2", "death_star", false),
        ("death_star", "input_1", false),
        ("death_star", "input_2", false),
    ]
    columns = [:from_asset, :to_asset, :is_transport]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_flow"
    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_2", "death_star", 2025, 1, 1, 1),
        (3, "death_star", "input_1", 2025, 1, 1, 1),
        (4, "death_star", "input_2", 2025, 1, 1, 1),
    ]
    columns = [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_vintage_flow"
    table_rows = [
        (1, "input_1", "death_star", 2025, 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 2020, 1, 1, 1),
    ]
    columns = [
        :id,
        :from_asset,
        :to_asset,
        :milestone_year,
        :commission_year,
        :rep_period,
        :time_block_start,
        :time_block_end,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:flow, :vintage_flow)
    )
    TulipaEnergyModel.add_flow_variables!(connection, model, variables)
    TulipaEnergyModel.add_vintage_flow_variables!(connection, model, variables)

    table_name = "cons_vintage_flow_sum_semi_compact_method"
    table_rows = [(1, "input_1", "death_star", 2025, 1, 1, 1)]
    columns = [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    constraints = let key = :vintage_flow_sum_semi_compact_method
        Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
            key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key"),
        )
    end

    TulipaEnergyModel.add_vintage_flow_sum_constraints!(connection, model, variables, constraints)

    # Test the constraints
    var_flow = variables[:flow].container
    var_vintage_flow = variables[:vintage_flow].container

    expected_cons =
        [JuMP.@build_constraint(var_vintage_flow[1] + var_vintage_flow[2] == var_flow[1])]
    observed_cons = _get_cons_object(model, :vintage_flow_sum_semi_compact_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
