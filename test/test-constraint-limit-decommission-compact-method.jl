@testset "Test add_limit_decommission_compact_method_constraints!" begin
    # Setup a temporary DuckDB connection and model
    connection = _multi_year_fixture()
    model = JuMP.Model()

    # Create variable tables
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
    _create_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_flows_decommission"
    columns_with_types = [
        :id => Int,
        :from_asset => String,
        :to_asset => String,
        :milestone_year => Int,
        :commission_year => Int,
        :investment_integer => Bool,
    ]
    _create_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_assets_investment_energy"
    columns_with_types = [:id => Int, :asset => String, :milestone_year => Int]
    _create_table_for_tests(connection, table_name, columns_with_types)

    table_name = "var_assets_decommission_energy"
    columns_with_types =
        [:id => Int, :asset => String, :milestone_year => Int, :commission_year => Int]
    _create_table_for_tests(connection, table_name, columns_with_types)

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for key in (
            :assets_investment,
            :assets_decommission,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )
    # Create JuMP variables
    TulipaEnergyModel.add_investment_variables!(model, variables)
    TulipaEnergyModel.add_decommission_variables!(model, variables)

    # Create expressions
    expressions = Dict{Symbol,TulipaEnergyModel.TulipaExpression}()
    TulipaEnergyModel.create_multi_year_expressions!(connection, model, variables, expressions)
    expr_avail_compact_method =
        expressions[:available_asset_units_compact_method].expressions[:assets]

    # Create constraint tables
    table_name = "cons_limit_decommission_compact_method"
    table_rows = [(1, "wind", 2030, 2020), (2, "wind", 2050, 2030)]
    columns = [:id, :asset, :milestone_year, :commission_year]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for
        key in (:limit_decommission_compact_method,)
    )

    # Create JuMP constraints
    TulipaEnergyModel.add_limit_decommission_compact_method_constraints!(
        connection,
        model,
        expr_avail_compact_method,
        constraints,
    )

    var_assets_investment = variables[:assets_investment].container
    var_assets_decommission = variables[:assets_decommission].container

    expected_cons = [
        JuMP.@build_constraint(0.07 - var_assets_decommission[1] ≥ 0),
        JuMP.@build_constraint(0.02 + var_assets_investment[1] - var_assets_decommission[2] ≥ 0)
    ]
    observed_cons = _get_cons_object(model, :limit_decommission_compact_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end
