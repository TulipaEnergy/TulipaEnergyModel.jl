@testset "Test add_dc_power_flow_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset table
    table_rows = [("input_1", "none"), ("input_2", "none")]
    asset = DataFrame(table_rows, [:asset, :investment_method])
    DuckDB.register_data_frame(connection, asset, "asset")

    table_rows = [("input_1", "death_star", true), ("input_2", "death_star", true)]
    flow = DataFrame(table_rows, [:from_asset, :to_asset, :is_transport])
    DuckDB.register_data_frame(connection, flow, "flow")

    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 1, 2, 5),
        (3, "input_2", "death_star", 2025, 1, 1, 2),
        (4, "input_2", "death_star", 2025, 1, 3, 5),
    ]
    var_flow = DataFrame(
        table_rows,
        [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(connection, var_flow, "var_flow")

    table_rows = [
        (1, "input_1", 2025, 1, 1, 3),
        (2, "input_1", 2025, 1, 4, 5),
        (3, "death_star", 2025, 1, 1, 5),
    ]
    electricity_angle =
        DataFrame(table_rows, [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end])
    DuckDB.register_data_frame(connection, electricity_angle, "var_electricity_angle")

    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 1, 2, 3),
        (3, "input_1", "death_star", 2025, 1, 4, 5),
    ]
    cons_dc_power_flow = DataFrame(
        table_rows,
        [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(connection, cons_dc_power_flow, "cons_dc_power_flow")

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:flow, :electricity_angle)
    )
    TulipaEnergyModel.add_flow_variables!(connection, model, variables)
    TulipaEnergyModel.add_power_flow_variables!(model, variables)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for
        key in (:dc_power_flow,)
    )

    table_rows = [(2025, true)]
    year_data = DataFrame(table_rows, [:year, :is_milestone])
    DuckDB.register_data_frame(connection, year_data, "year_data")

    table_rows =
        [("input_1", "death_star", 2025, true, 0.5), ("input_2", "death_star", 2025, false, 0.4)]
    flow_milestone =
        DataFrame(table_rows, [:from_asset, :to_asset, :milestone_year, :dc_opf, :reactance])
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")

    model_parameters = TulipaEnergyModel.ModelParameters(connection)

    TulipaEnergyModel.add_dc_power_flow_constraints!(
        connection,
        model,
        variables,
        constraints,
        model_parameters,
    )

    # components of the expected constraints
    expected_ids = [(1, 1, 3), (2, 1, 3), (2, 2, 3)]

    # parameters for the expected constraints
    power_system_base = 100
    reactance = 0.5

    # test the constraints
    var_flow = variables[:flow].container
    var_electricity_angle = variables[:electricity_angle].container

    expected_cons = []
    for i in 1:length(model[:dc_power_flow])
        flow_id, from_asset_id, to_asset_id = expected_ids[i]
        expected_con = JuMP.@build_constraint(
            reactance * var_flow[flow_id] -
            power_system_base *
            (var_electricity_angle[from_asset_id] - var_electricity_angle[to_asset_id]) == 0
        )
        push!(expected_cons, expected_con)
    end
    observed_cons = [JuMP.constraint_object(constraint) for constraint in model[:dc_power_flow]]
    @test _is_constraint_equal(expected_cons, observed_cons)
end
