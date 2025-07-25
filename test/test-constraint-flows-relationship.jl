@testset "Test add_flows_relationships_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    table_name = "asset"
    table_rows = [("input_1", "none"), ("input_2", "none"), ("death_star", "none")]
    columns = [:asset, :investment_method]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "flow"
    table_rows = [
        ("input_1", "death_star", false),
        ("input_2", "death_star", false),
        ("death_star", "output_1", false),
        ("death_star", "output_2", false),
    ]
    columns = [:from_asset, :to_asset, :is_transport]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_flow"
    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 1, 2, 5),
        (3, "input_2", "death_star", 2025, 1, 1, 2),
        (4, "input_2", "death_star", 2025, 1, 3, 5),
        (5, "death_star", "output_1", 2025, 1, 1, 3),
        (6, "death_star", "output_1", 2025, 1, 4, 5),
        (7, "death_star", "output_2", 2025, 1, 1, 4),
        (8, "death_star", "output_2", 2025, 1, 5, 5),
    ]
    columns = [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_flows_relationships"
    table_rows = [
        (
            1,
            "death_star_output_1_death_star_output_2",
            2025,
            1,
            1,
            4,
            "death_star",
            "output_1",
            "death_star",
            "output_2",
            "==",
            0.0,
            1.0,
        ),
        (
            2,
            "death_star_output_1_death_star_output_2",
            2025,
            1,
            5,
            5,
            "death_star",
            "output_1",
            "death_star",
            "output_2",
            "==",
            0.0,
            1.0,
        ),
        (
            3,
            "death_star_output_1_input_1_death_star",
            2025,
            1,
            1,
            3,
            "death_star",
            "output_1",
            "input_1",
            "death_star",
            ">=",
            1.0,
            10.0,
        ),
        (
            4,
            "death_star_output_1_input_1_death_star",
            2025,
            1,
            4,
            5,
            "death_star",
            "output_1",
            "input_1",
            "death_star",
            ">=",
            1.0,
            10.0,
        ),
        (
            5,
            "input_1_death_star_death_star_output_1",
            2025,
            1,
            1,
            3,
            "input_1",
            "death_star",
            "death_star",
            "output_1",
            "<=",
            -1.0,
            -1.0,
        ),
        (
            6,
            "input_1_death_star_death_star_output_1",
            2025,
            1,
            4,
            5,
            "input_1",
            "death_star",
            "death_star",
            "output_1",
            "<=",
            -1.0,
            -1.0,
        ),
        (
            7,
            "input_1_death_star_input_2_death_star",
            2025,
            1,
            1,
            2,
            "input_1",
            "death_star",
            "input_2",
            "death_star",
            "==",
            0.0,
            1.0,
        ),
        (
            8,
            "input_1_death_star_input_2_death_star",
            2025,
            1,
            3,
            5,
            "input_1",
            "death_star",
            "input_2",
            "death_star",
            "==",
            0.0,
            1.0,
        ),
    ]
    columns = [
        :id,
        :asset,
        :year,
        :rep_period,
        :time_block_start,
        :time_block_end,
        :flow_1_from_asset,
        :flow_1_to_asset,
        :flow_2_from_asset,
        :flow_2_to_asset,
        :sense,
        :constant,
        :ratio,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for key in (:flow,)
    )
    TulipaEnergyModel.add_flow_variables!(connection, model, variables)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for
        key in (:flows_relationships,)
    )
    TulipaEnergyModel.add_flows_relationships_constraints!(
        connection,
        model,
        variables,
        constraints,
    )

    # components of the expected constraints
    expected_coefficients =
        [[3, 1, -4], [1, -1], [-10, -20, 3], [-20, 2], [1, 2, 3], [2, 2], [1, 1, -2], [3, -3]]
    expected_flows_ids =
        [[5, 6, 7], [6, 8], [1, 2, 5], [2, 6], [1, 2, 5], [2, 6], [1, 2, 3], [2, 4]]
    expected_senses = [
        MathOptInterface.EqualTo(0.0),
        MathOptInterface.EqualTo(0.0),
        MathOptInterface.GreaterThan(0.0),
        MathOptInterface.GreaterThan(0.0),
        MathOptInterface.LessThan(0.0),
        MathOptInterface.LessThan(0.0),
        MathOptInterface.EqualTo(0.0),
        MathOptInterface.EqualTo(0.0),
    ]
    expected_rhs = [0, 0, 1, 1, -1, -1, 0, 0]

    # test the constraints
    var_flow = variables[:flow].container
    expected_cons = [
        JuMP.@build_constraint(
            sum(e_coef * var_flow[id] for (id, e_coef) in zip(e_flows_ids, e_coefs)) - e_rhs in
            e_sense
        ) for (e_flows_ids, e_coefs, e_rhs, e_sense) in
        zip(expected_flows_ids, expected_coefficients, expected_rhs, expected_senses)
    ]
    observed_cons = _get_cons_object(model, :flows_relationships)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
