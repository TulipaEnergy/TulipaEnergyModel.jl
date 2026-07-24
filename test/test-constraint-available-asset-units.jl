@testitem "Test add_available_asset_units_constraints!" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    _create_table_for_tests(
        connection,
        "expr_available_asset_units_aggregated_vintage_method",
        [(1, "aggregated_asset", 2050, 2050)],
        [:id, :asset, :milestone_year, :commission_year],
    )
    _create_table_for_tests(
        connection,
        "expr_available_asset_units_compact_vintage_method",
        [(1, "compact_asset", 2050, 2030), (2, "compact_asset", 2050, 2050)],
        [:id, :asset, :milestone_year, :commission_year],
    )
    _create_table_for_tests(
        connection,
        "cons_min_available_asset_units",
        [(1, "aggregated_asset", 2050, 2.0), (2, "compact_asset", 2050, 3.0)],
        [:id, :asset, :milestone_year, :rhs],
    )
    _create_table_for_tests(
        connection,
        "cons_max_available_asset_units",
        [(1, "aggregated_asset", 2050, 5.0), (2, "compact_asset", 2050, 7.0)],
        [:id, :asset, :milestone_year, :rhs],
    )

    expr_aggregated =
        TEM.TulipaExpression(connection, "expr_available_asset_units_aggregated_vintage_method")
    expr_compact =
        TEM.TulipaExpression(connection, "expr_available_asset_units_compact_vintage_method")
    JuMP.@variable(model, aggregated_units)
    JuMP.@variable(model, compact_units[1:2])
    expr_aggregated.expressions[:assets] = [JuMP.@expression(model, aggregated_units)]
    expr_compact.expressions[:assets] =
        [JuMP.@expression(model, compact_units[1]), JuMP.@expression(model, compact_units[2])]
    expressions = Dict(
        :available_asset_units_aggregated_vintage_method => expr_aggregated,
        :available_asset_units_compact_vintage_method => expr_compact,
    )
    constraints = Dict(
        :min_available_asset_units =>
            TEM.TulipaConstraint(connection, "cons_min_available_asset_units"),
        :max_available_asset_units =>
            TEM.TulipaConstraint(connection, "cons_max_available_asset_units"),
    )

    TEM.add_available_asset_units_constraints!(connection, model, expressions, constraints)

    expected_min_cons = [
        JuMP.@build_constraint(aggregated_units >= 2),
        JuMP.@build_constraint(compact_units[1] + compact_units[2] >= 3),
    ]
    expected_max_cons = [
        JuMP.@build_constraint(aggregated_units <= 5),
        JuMP.@build_constraint(compact_units[1] + compact_units[2] <= 7),
    ]
    @test _is_constraint_equal(
        expected_min_cons,
        _get_cons_object(model, :min_available_asset_units),
    )
    @test _is_constraint_equal(
        expected_max_cons,
        _get_cons_object(model, :max_available_asset_units),
    )
end

@testitem "Test available asset units constraints are optional" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _create_empty_table_for_tests(
        connection,
        "expr_available_asset_units_aggregated_vintage_method",
        [:id => Int, :asset => String, :milestone_year => Int, :commission_year => Int],
    )
    _create_empty_table_for_tests(
        connection,
        "expr_available_asset_units_compact_vintage_method",
        [:id => Int, :asset => String, :milestone_year => Int, :commission_year => Int],
    )
    _create_empty_table_for_tests(
        connection,
        "cons_min_available_asset_units",
        [:id => Int, :asset => String, :milestone_year => Int, :rhs => Float64],
    )
    _create_empty_table_for_tests(
        connection,
        "cons_max_available_asset_units",
        [:id => Int, :asset => String, :milestone_year => Int, :rhs => Float64],
    )

    expressions = Dict(
        :available_asset_units_aggregated_vintage_method => TEM.TulipaExpression(
            connection,
            "expr_available_asset_units_aggregated_vintage_method",
        ),
        :available_asset_units_compact_vintage_method => TEM.TulipaExpression(
            connection,
            "expr_available_asset_units_compact_vintage_method",
        ),
    )
    for expr in values(expressions)
        expr.expressions[:assets] = JuMP.AffExpr[]
    end
    constraints = Dict(
        :min_available_asset_units =>
            TEM.TulipaConstraint(connection, "cons_min_available_asset_units"),
        :max_available_asset_units =>
            TEM.TulipaConstraint(connection, "cons_max_available_asset_units"),
    )
    model = JuMP.Model()

    TEM.add_available_asset_units_constraints!(connection, model, expressions, constraints)

    @test isempty(model[:min_available_asset_units])
    @test isempty(model[:max_available_asset_units])
end
