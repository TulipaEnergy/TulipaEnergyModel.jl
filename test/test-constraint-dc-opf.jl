@testset "Test add_dc_power_flow_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame
    # This first table is only necessary because we have a left join of var_flow with the asset
    table_name = "asset"
    table_rows = [("input_1", "none"), ("input_2", "none")]
    columns = [:asset, :investment_method]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "flow"
    table_rows = [("input_1", "death_star", true), ("input_2", "death_star", true)]
    columns = [:from_asset, :to_asset, :is_transport]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_flow"
    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 1, 2, 5),
        (3, "input_2", "death_star", 2025, 1, 1, 2),
        (4, "input_2", "death_star", 2025, 1, 3, 5),
    ]
    columns = [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_electricity_angle"
    table_rows = [
        (1, "input_1", 2025, 1, 1, 3),
        (2, "input_1", 2025, 1, 4, 5),
        (3, "death_star", 2025, 1, 1, 5),
    ]
    columns = [:id, :asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_dc_power_flow"
    table_rows = [
        (1, "input_1", "death_star", 2025, 1, 1, 1),
        (2, "input_1", "death_star", 2025, 1, 2, 3),
        (3, "input_1", "death_star", 2025, 1, 4, 5),
    ]
    columns = [:id, :from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end]
    _create_table_for_tests(connection, table_name, table_rows, columns)

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

    table_name = "year_data"
    table_rows = [(2025, true)]
    columns = [:year, :is_milestone]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "flow_milestone"
    table_rows =
        [("input_1", "death_star", 2025, true, 0.5), ("input_2", "death_star", 2025, false, 0.4)]
    columns = [:from_asset, :to_asset, :milestone_year, :dc_opf, :reactance]
    _create_table_for_tests(connection, table_name, table_rows, columns)

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

    expected_cons = [
        JuMP.@build_constraint(
            reactance * var_flow[flow_id] -
            power_system_base *
            (var_electricity_angle[from_asset_id] - var_electricity_angle[to_asset_id]) == 0
        ) for (flow_id, from_asset_id, to_asset_id) in expected_ids
    ]
    observed_cons = _get_cons_object(model, :dc_power_flow)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
