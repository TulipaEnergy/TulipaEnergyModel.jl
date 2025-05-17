@testset "Test add_flows_relationships_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    table_rows = [
        ("input_1", "death_star", false),
        ("input_2", "death_star", false),
        ("death_star", "output_1", false),
        ("death_star", "output_2", false),
    ]
    flow = DataFrame(table_rows, [:from_asset, :to_asset, :is_transport])
    DuckDB.register_data_frame(connection, flow, "flow")

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
    var_flow = DataFrame(
        table_rows,
        [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(connection, var_flow, "var_flow")

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
    cons_flows_relationships = DataFrame(
        table_rows,
        [
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
        ],
    )
    DuckDB.register_data_frame(connection, cons_flows_relationships, "cons_flows_relationships")

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
    for (i, constraint) in enumerate(model[:flows_relationships])
        observed_con = JuMP.constraint_object(constraint)
        expected_con = JuMP.@build_constraint(
            sum(
                expected_coefficients[i][j] * var_flow[id] for
                (j, id) in enumerate(expected_flows_ids[i])
            ) - expected_rhs[i] in expected_senses[i]
        )
        @test _is_constraint_equal(observed_con, expected_con)
    end
end
