@testset "Test add_group_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create mock tables for testing using register_data_frame

    # Asset table - defines which assets belong to which group
    asset_rows = [
        ("wind_1", "renewable_group", 100.0, 2025),
        ("wind_2", "renewable_group", 150.0, 2025),
        ("solar_1", "renewable_group", 80.0, 2025),
        ("gas_1", "fossil_group", 200.0, 2025),
        ("gas_2", "fossil_group", 250.0, 2025),
    ]
    asset = DataFrame(asset_rows, [:asset, :group, :capacity, :milestone_year])
    DuckDB.register_data_frame(connection, asset, "asset")

    # Group asset table - defines the groups
    group_asset_rows = [("renewable_group", "renewable"), ("fossil_group", "fossil")]
    group_asset = DataFrame(group_asset_rows, [:name, :type])
    DuckDB.register_data_frame(connection, group_asset, "group_asset")

    # Variable assets investment table
    var_assets_investment_rows = [
        (1, "wind_1", 2025, true, 100.0, 500.0),
        (2, "wind_2", 2025, true, 150.0, 600.0),
        (3, "solar_1", 2025, true, 80.0, 400.0),
        (4, "gas_1", 2025, true, 200.0, 800.0),
        (5, "gas_2", 2025, true, 250.0, 1000.0),
    ]
    var_assets_investment = DataFrame(
        var_assets_investment_rows,
        [:id, :asset, :milestone_year, :investment_integer, :capacity, :investment_limit],
    )
    DuckDB.register_data_frame(connection, var_assets_investment, "var_assets_investment")

    # Group max investment limit constraints
    cons_group_max_investment_limit_rows =
        [(1, "renewable_group", 1000.0), (2, "fossil_group", 1200.0)]
    cons_group_max_investment_limit =
        DataFrame(cons_group_max_investment_limit_rows, [:id, :name, :max_investment_limit])
    DuckDB.register_data_frame(
        connection,
        cons_group_max_investment_limit,
        "cons_group_max_investment_limit",
    )

    # Group min investment limit constraints
    cons_group_min_investment_limit_rows =
        [(1, "renewable_group", 200.0), (2, "fossil_group", 100.0)]
    cons_group_min_investment_limit =
        DataFrame(cons_group_min_investment_limit_rows, [:id, :name, :min_investment_limit])
    DuckDB.register_data_frame(
        connection,
        cons_group_min_investment_limit,
        "cons_group_min_investment_limit",
    )

    # Create empty tables for other investment variables that are required
    df_flows_investment = DataFrame(;
        id = Int[],
        from_asset = String[],
        to_asset = String[],
        milestone_year = Int[],
        investment_integer = Bool[],
        capacity = Float64[],
        investment_limit = Float64[],
    )
    DuckDB.register_data_frame(connection, df_flows_investment, "var_flows_investment")

    df_assets_decommission = DataFrame(;
        id = Int[],
        asset = String[],
        milestone_year = Int[],
        commission_year = Int[],
        investment_integer = Bool[],
    )
    DuckDB.register_data_frame(connection, df_assets_decommission, "var_assets_decommission")

    df_flows_decommission = DataFrame(;
        id = Int[],
        from_asset = String[],
        to_asset = String[],
        milestone_year = Int[],
        commission_year = Int[],
        investment_integer = Bool[],
    )
    DuckDB.register_data_frame(connection, df_flows_decommission, "var_flows_decommission")

    df_assets_investment_energy = DataFrame(;
        id = Int[],
        asset = String[],
        milestone_year = Int[],
        investment_integer_storage_energy = Bool[],
        capacity_storage_energy = Float64[],
        investment_limit_storage_energy = Float64[],
    )
    DuckDB.register_data_frame(
        connection,
        df_assets_investment_energy,
        "var_assets_investment_energy",
    )

    df_assets_decommission_energy = DataFrame(;
        id = Int[],
        asset = String[],
        milestone_year = Int[],
        commission_year = Int[],
        investment_integer_storage_energy = Bool[],
    )
    DuckDB.register_data_frame(
        connection,
        df_assets_decommission_energy,
        "var_assets_decommission_energy",
    )

    # Create variables
    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for key in (
            :assets_investment,
            :flows_investment,
            :assets_decommission,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )
    TulipaEnergyModel.add_investment_variables!(model, variables)

    # Create constraints
    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for
        key in (:group_max_investment_limit, :group_min_investment_limit)
    )

    # Add group constraints
    TulipaEnergyModel.add_group_constraints!(connection, model, variables, constraints)

    # Test the max investment limit constraints
    var_assets_investment_container = variables[:assets_investment].container

    # Test renewable group max constraint: 100*x1 + 150*x2 + 80*x3 ≤ 1000
    renewable_max_constraint = model[:investment_group_max_limit][1]
    observed_con = JuMP.constraint_object(renewable_max_constraint)
    expected_con = JuMP.@build_constraint(
        100.0 * var_assets_investment_container[1] +
        150.0 * var_assets_investment_container[2] +
        80.0 * var_assets_investment_container[3] ≤ 1000.0
    )
    @test _is_constraint_equal(observed_con, expected_con)

    # Test fossil group max constraint: 200*x4 + 250*x5 ≤ 1200
    fossil_max_constraint = model[:investment_group_max_limit][2]
    observed_con = JuMP.constraint_object(fossil_max_constraint)
    expected_con = JuMP.@build_constraint(
        200.0 * var_assets_investment_container[4] + 250.0 * var_assets_investment_container[5] ≤ 1200.0
    )
    @test _is_constraint_equal(observed_con, expected_con)

    # Test the min investment limit constraints

    # Test renewable group min constraint: 100*x1 + 150*x2 + 80*x3 ≥ 200
    renewable_min_constraint = model[:investment_group_min_limit][1]
    observed_con = JuMP.constraint_object(renewable_min_constraint)
    expected_con = JuMP.@build_constraint(
        100.0 * var_assets_investment_container[1] +
        150.0 * var_assets_investment_container[2] +
        80.0 * var_assets_investment_container[3] ≥ 200.0
    )
    @test _is_constraint_equal(observed_con, expected_con)

    # Test fossil group min constraint: 200*x4 + 250*x5 ≥ 100
    fossil_min_constraint = model[:investment_group_min_limit][2]
    observed_con = JuMP.constraint_object(fossil_min_constraint)
    expected_con = JuMP.@build_constraint(
        200.0 * var_assets_investment_container[4] + 250.0 * var_assets_investment_container[5] ≥ 100.0
    )
    @test _is_constraint_equal(observed_con, expected_con)
end
