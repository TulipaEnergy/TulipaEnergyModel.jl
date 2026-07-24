@testsnippet ConsInvestmentGroupSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_investment_group_problem()
        tulipa = TB.TulipaData()

        TB.add_asset!(tulipa, "producer1", :producer; investable = true)
        TB.add_asset!(tulipa, "producer2", :producer; investable = true)
        TB.add_asset!(
            tulipa,
            "producer3",
            :producer;
            investable = true,
            vintage_method = "compact_profiles",
        )
        for asset in ("producer1", "producer2", "producer3"), milestone_year in (2030, 2050)
            TB.attach_profile!(tulipa, asset, :availability, milestone_year, ones(6))
        end

        connection = TB.create_connection(tulipa, TEM.schema)

        # There is no way to inform these via TB yet
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE investment_group_asset (name VARCHAR, milestone_year INT, constraint_sense VARCHAR, rhs DOUBLE, invest_method VARCHAR);
            INSERT INTO investment_group_asset VALUES ('group1', 2030, '<=', 7700, 'use_only_investment_units');
            INSERT INTO investment_group_asset VALUES ('group1', 2050, '>=', 3300, 'use_only_investment_units');
            INSERT INTO investment_group_asset VALUES ('group2', 2030, '==', 1234, 'use_only_investment_units');
            INSERT INTO investment_group_asset VALUES ('group3', 2050, '<=', 987, 'use_available_units');
            INSERT INTO investment_group_asset VALUES ('group4', 2050, '==', 4321, 'none');
            """,
        )
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE investment_group_asset_membership (group_name VARCHAR, milestone_year INT, asset VARCHAR, coefficient DOUBLE);
            INSERT INTO investment_group_asset_membership VALUES ('group1', 2030, 'producer1', 3.14);
            INSERT INTO investment_group_asset_membership VALUES ('group1', 2030, 'producer2', 6.66);
            INSERT INTO investment_group_asset_membership VALUES ('group1', 2050, 'producer2', 2.51);
            INSERT INTO investment_group_asset_membership VALUES ('group2', 2030, 'producer1', 0.73);
            INSERT INTO investment_group_asset_membership VALUES ('group3', 2050, 'producer1', 2.0);
            INSERT INTO investment_group_asset_membership VALUES ('group3', 2050, 'producer3', 4.2);
            INSERT INTO investment_group_asset_membership VALUES ('group4', 2050, 'producer2', 3.45);
            """,
        )

        layout = TC.ProfilesTableLayout(; year = :milestone_year)
        TC.dummy_cluster!(connection; layout)

        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return connection, energy_problem
    end
end

@testitem "Constraints for investment groups" setup = [CommonSetup, ConsInvestmentGroupSetup] tags =
    [:unit, :constraint, :fast] begin
    con, ep = create_investment_group_problem()

    var_assets_investment = ep.variables[:assets_investment].container
    var_lookup = Dict(
        (row.asset, row.milestone_year) => var_assets_investment[row.id] for
        row in ep.variables[:assets_investment].indices
    )
    expr_available_asset_units_aggregated =
        ep.expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    expr_available_asset_units_compact =
        ep.expressions[:available_asset_units_compact_vintage_method].expressions[:assets]
    aggregated_ids = [
        row.id for
        row in ep.expressions[:available_asset_units_aggregated_vintage_method].indices if
        row.asset == "producer1" && row.milestone_year == 2050
    ]
    compact_ids = [
        row.id for
        row in ep.expressions[:available_asset_units_compact_vintage_method].indices if
        row.asset == "producer3" && row.milestone_year == 2050
    ]
    @test !isempty(aggregated_ids)
    @test !isempty(compact_ids)

    expected_cons_lookup = Dict(
        ("group1", 2030) => JuMP.@build_constraint(
            var_lookup["producer1", 2030] * 3.14 + var_lookup["producer2", 2030] * 6.66 <= 7700
        ),
        ("group1", 2050) =>
            JuMP.@build_constraint(var_lookup["producer2", 2050] * 2.51 >= 3300),
        ("group2", 2030) =>
            JuMP.@build_constraint(var_lookup["producer1", 2030] * 0.73 == 1234),
        ("group3", 2050) => JuMP.@build_constraint(
            sum(2.0 * expr_available_asset_units_aggregated[id] for id in aggregated_ids) +
            sum(4.2 * expr_available_asset_units_compact[id] for id in compact_ids) <= 987
        ),
        # No group4, because invest_method is none
    )
    observed_cons = _get_cons_object(ep.model, :investment_group)
    observed_cons_lookup = Dict(
        (row.name, row.milestone_year) => observed_cons[row.id] for
        row in DuckDB.query(con, "FROM cons_group_investment")
    )
    @test Set(keys(observed_cons_lookup)) == Set(keys(expected_cons_lookup))
    for ((group_name, milestone_year), observed_cons) in observed_cons_lookup
        @test _is_constraint_equal(expected_cons_lookup[group_name, milestone_year], observed_cons)
    end
end
@testitem "Available-unit group constraints aggregate compact vintages" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.query(
        connection,
        """
        CREATE TABLE cons_group_investment (
            id BIGINT,
            name VARCHAR,
            milestone_year INT,
            invest_method VARCHAR,
            constraint_sense VARCHAR,
            rhs DOUBLE
        );
        INSERT INTO cons_group_investment VALUES (1, 'group1', 2050, 'use_available_units', '<=', 100.0);
        CREATE TABLE investment_group_asset (
            name VARCHAR,
            milestone_year INT,
            invest_method VARCHAR
        );
        INSERT INTO investment_group_asset VALUES ('group1', 2050, 'use_available_units');
        CREATE TABLE investment_group_asset_membership (
            group_name VARCHAR,
            milestone_year INT,
            asset VARCHAR,
            coefficient DOUBLE
        );
        INSERT INTO investment_group_asset_membership VALUES ('group1', 2050, 'aggregated_asset', 2.0);
        INSERT INTO investment_group_asset_membership VALUES ('group1', 2050, 'compact_asset', 3.0);
        CREATE TABLE var_assets_investment (id BIGINT, asset VARCHAR, milestone_year INT);
        CREATE TABLE expr_available_asset_units_aggregated_vintage_method (
            id BIGINT,
            asset VARCHAR,
            milestone_year INT,
            commission_year INT
        );
        INSERT INTO expr_available_asset_units_aggregated_vintage_method VALUES (1, 'aggregated_asset', 2050, 2050);
        CREATE TABLE expr_available_asset_units_compact_vintage_method (
            id BIGINT,
            asset VARCHAR,
            milestone_year INT,
            commission_year INT
        );
        INSERT INTO expr_available_asset_units_compact_vintage_method VALUES (1, 'compact_asset', 2050, 2030);
        INSERT INTO expr_available_asset_units_compact_vintage_method VALUES (2, 'compact_asset', 2050, 2050);
        """,
    )

    model = JuMP.Model()
    variables = Dict(:assets_investment => TEM.TulipaVariable(connection, "var_assets_investment"))
    expr_available_asset_units_aggregated =
        TEM.TulipaExpression(connection, "expr_available_asset_units_aggregated_vintage_method")
    expr_available_asset_units_compact =
        TEM.TulipaExpression(connection, "expr_available_asset_units_compact_vintage_method")
    JuMP.@variable(model, available_units_aggregated)
    JuMP.@variable(model, available_units_compact[1:2])
    TEM.attach_expression!(
        expr_available_asset_units_aggregated,
        :assets,
        [JuMP.@expression(model, available_units_aggregated + 0)],
    )
    TEM.attach_expression!(
        expr_available_asset_units_compact,
        :assets,
        [JuMP.@expression(model, available_units_compact[id] + 0) for id in 1:2],
    )
    expressions = Dict(
        :available_asset_units_aggregated_vintage_method =>
            expr_available_asset_units_aggregated,
        :available_asset_units_compact_vintage_method => expr_available_asset_units_compact,
    )
    constraints =
        Dict(:group_investment => TEM.TulipaConstraint(connection, "cons_group_investment"))

    TEM.add_investment_group_constraints!(connection, model, variables, expressions, constraints)

    observed_constraint = only(_get_cons_object(model, :investment_group))
    expected_constraint = JuMP.@build_constraint(
        2.0 * available_units_aggregated +
        3.0 * available_units_compact[1] +
        3.0 * available_units_compact[2] <= 100.0
    )
    @test _is_constraint_equal(expected_constraint, observed_constraint)
end
