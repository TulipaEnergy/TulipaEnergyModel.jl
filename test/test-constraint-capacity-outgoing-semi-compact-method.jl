@testset "Test add_capacity_outgoing_semi_compact_method_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = _multi_year_fixture()
    # Set the investment method to 'semi-compact' for wind
    DuckDB.query(
        connection,
        """
        UPDATE asset SET investment_method = 'semi-compact' WHERE asset = 'wind';
        """,
    )

    model = JuMP.Model()

    # Create variable tables
    table_name = "var_vintage_flow"
    x = 1
    table_rows = [
        (1, "wind", "demand", 2030, 2020, x, x, x, 1.0, 1.0),
        (2, "wind", "demand", 2030, 2030, x, x, x, 1.0, 1.0),
        (3, "wind", "demand", 2050, 2030, x, x, x, 1.0, 1.0),
        (4, "wind", "demand", 2050, 2050, x, x, x, 1.0, 1.0),
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
        :capacity_coefficient,
        :conversion_coefficient,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_assets_investment"
    table_rows = [(1, "wind", 2030, true, 50, Inf), (2, "wind", 2050, true, 50, Inf)]
    columns = [:id, :asset, :milestone_year, :investment_integer, :capacity, :investment_limit]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_assets_decommission"
    table_rows = [(1, "wind", 2030, 2020, true), (2, "wind", 2050, 2030, true)]
    columns = [:id, :asset, :milestone_year, :commission_year, :investment_integer]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "var_flows_investment"
    columns_with_types = [
        :id => Int,
        :from_asset => String,
        :to_asset => String,
        :milestone_year => Int,
        :investment_integer => Bool,
        :capacity => Float64,
        :investment_limit => Float64,
    ]
    _create_empty_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_flows_decommission"
    columns_with_types = [
        :id => Int,
        :from_asset => String,
        :to_asset => String,
        :milestone_year => Int,
        :commission_year => Int,
        :investment_integer => Bool,
    ]
    _create_empty_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_assets_investment_energy"
    columns_with_types = [:id => Int, :asset => String, :milestone_year => Int]
    _create_empty_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_assets_decommission_energy"
    columns_with_types =
        [:id => Int, :asset => String, :milestone_year => Int, :commission_year => Int]
    _create_empty_table_for_tests(connection, table_name, columns_with_types)

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for key in (
            :assets_investment,
            :assets_decommission,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
            :vintage_flow,
        )
    )
    # Create JuMP variables
    TulipaEnergyModel.add_vintage_flow_variables!(connection, model, variables)
    TulipaEnergyModel.add_investment_variables!(model, variables)
    TulipaEnergyModel.add_decommission_variables!(model, variables)

    # Create expressions
    expressions = Dict{Symbol,TulipaEnergyModel.TulipaExpression}()
    TulipaEnergyModel.create_multi_year_expressions!(connection, model, variables, expressions)
    expr_avail_compact_method =
        expressions[:available_asset_units_compact_method].expressions[:assets]

    # Create constraint
    table_name = "cons_capacity_outgoing_semi_compact_method"
    table_rows = [
        (1, "wind", 2030, 2020, 1, 1, 1),
        (2, "wind", 2030, 2030, 1, 1, 1),
        (3, "wind", 2050, 2030, 1, 1, 1),
        (4, "wind", 2050, 2050, 1, 1, 1),
    ]
    columns = [
        :id,
        :asset,
        :milestone_year,
        :commission_year,
        :rep_period,
        :time_block_start,
        :time_block_end,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)
    constraints = let key = :capacity_outgoing_semi_compact_method
        Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
            key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key"),
        )
    end

    # Create profiles
    TulipaEnergyModel.create_internal_tables!(connection)
    profiles = TulipaEnergyModel.prepare_profiles_structure(connection)

    #=
    # creating a workspace with enough entries for any of the representative periods or normal periods
    maximum_num_timesteps = TulipaEnergyModel.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT MAX(num_timesteps::BIGINT) FROM rep_periods_data"),
    )::Int64

    maximum_num_periods = TulipaEnergyModel.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT MAX(period::BIGINT) FROM rep_periods_mapping"),
    )::Int64
    Tmax = max(maximum_num_timesteps, maximum_num_periods)
    workspace = [Dict{Int,Float64}() for _ in 1:Tmax]

    # Add the expressions to the constraints
    TulipaEnergyModel.add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:capacity_outgoing_semi_compact_method],
        variables[:vintage_flow],
        workspace;
        use_highest_resolution = true,
        multiply_by_duration = false,
        multiply_by_capacity_coefficient = true,
        include_commission_year = true,
    )
    =#

    # Create JuMP constraints
    TulipaEnergyModel.add_capacity_outgoing_semi_compact_method_constraints!(
        connection,
        model,
        expr_avail_compact_method,
        constraints,
        profiles,
    )

    var_vintage_flow = variables[:vintage_flows].container

    expected_profiles = [
        profiles.rep_period[("availability-wind2020", 2030, 1)][1]
        profiles.rep_period[("availability-wind2030", 2030, 1)][1]
        profiles.rep_period[("availability-wind2030", 2050, 1)][1]
        profiles.rep_period[("availability-wind2050", 2050, 1)][1]
    ]
    expected_cons = [
        JuMP.@build_constraint(var ≤ profile * expr) for (var, profile, expr) in
        zip(var_vintage_flow, expected_profiles, expr_avail_compact_method)
    ]
    observed_cons = _get_cons_object(model, :max_output_flows_limit_semi_compact_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
