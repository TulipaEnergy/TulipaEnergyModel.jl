@testset "Test add_vintage_flow_sum_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset table
    table_rows = [("input_1", "semi-compact"), ("input_2", "compact"), ("death_star", "simple")]
    asset = DataFrame(table_rows, [:asset, :investment_method])
    DuckDB.register_data_frame(connection, asset, "asset")

    table_rows = [
        ("input_1", "death_star", false),
        ("input_2", "death_star", false),
        ("death_star", "input_1", false),
        ("death_star", "input_2", false),
    ]
    flow = DataFrame(table_rows, [:from_asset, :to_asset, :is_transport])
    DuckDB.register_data_frame(connection, flow, "flow")

    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_2", "death_star", 2025, 1, 1, 1),
        (3, "death_star", "input_1", 2025, 1, 1, 1),
        (4, "death_star", "input_2", 2025, 1, 1, 1),
    ]
    var_flow = DataFrame(
        table_rows,
        [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(connection, var_flow, "var_flow")

    table_rows = [
        (1, "input_1", "death_star", 2025, 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 2020, 1, 1, 1),
    ]
    var_vintage_flow = DataFrame(
        table_rows,
        [
            :id,
            :from_asset,
            :to_asset,
            :milestone_year,
            :commission_year,
            :rep_period,
            :time_block_start,
            :time_block_end,
        ],
    )
    DuckDB.register_data_frame(connection, var_vintage_flow, "var_vintage_flow")

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:flow, :vintage_flow)
    )
    TulipaEnergyModel.add_flow_variables!(connection, model, variables)
    TulipaEnergyModel.add_vintage_flow_variables!(connection, model, variables)

    table_rows = [(1, "input_1", "death_star", 2025, 1, 1, 1)]

    cons_vintage_flow_sum_semi_compact_method = DataFrame(
        table_rows,
        [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(
        connection,
        cons_vintage_flow_sum_semi_compact_method,
        "cons_vintage_flow_sum_semi_compact_method",
    )

    constraints = let key = :vintage_flow_sum_semi_compact_method
        Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
            key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key"),
        )
    end

    TulipaEnergyModel.add_vintage_flow_sum_constraints!(connection, model, variables, constraints)

    # Test the constraints
    var_flow = variables[:flow].container
    var_vintage_flow = variables[:vintage_flow].container

    expected_con =
        [JuMP.@build_constraint(var_vintage_flow[1] + var_vintage_flow[2] == var_flow[1])]

    observed_con =
        [JuMP.constraint_object(con) for con in model[:vintage_flow_sum_semi_compact_method]]

    for (expected, observed) in zip(expected_con, observed_con)
        @test _is_constraint_equal(expected, observed)
    end

    @test length(expected_con) == length(observed_con)
end
