@testsnippet ConsInvestmentGroupSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_investment_group_problem(assets, groups)
        tulipa = TB.TulipaData()

        for asset in assets
            TB.add_asset!(
                tulipa,
                asset.name,
                asset.kind;
                investable = asset.investable,
                vintage_method = asset.vintage_method,
            )
            for (milestone_year, profile) in asset.profiles
                TB.attach_profile!(tulipa, asset.name, :availability, milestone_year, profile)
            end
        end

        connection = TB.create_connection(tulipa, TEM.schema)

        function insert_rows(table_name, columns, rows)
            values = join(
                [
                    "(" *
                    join([
                        if value isa String
                            "'$(replace(value, "'" => "''"))'"
                        else
                            string(value)
                        end for value in row
                    ], ", ") *
                    ")" for row in rows
                ],
                ", ",
            )
            return DuckDB.query(
                connection,
                """
                CREATE OR REPLACE TABLE $table_name ($(join(columns, ", ")));
                INSERT INTO $table_name VALUES $values;
                """,
            )
        end

        insert_rows(
            "investment_group_asset",
            [
                "name VARCHAR",
                "milestone_year INT",
                "constraint_sense VARCHAR",
                "rhs DOUBLE",
                "invest_method VARCHAR",
            ],
            [
                (
                    group.name,
                    group.milestone_year,
                    group.constraint_sense,
                    group.rhs,
                    group.invest_method,
                ) for group in groups
            ],
        )
        insert_rows(
            "investment_group_asset_membership",
            ["group_name VARCHAR", "milestone_year INT", "asset VARCHAR", "coefficient DOUBLE"],
            [
                (group.name, group.milestone_year, membership.asset, membership.coefficient) for
                group in groups for membership in group.memberships
            ],
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
    assets = [
        (;
            name = "producer1",
            kind = :producer,
            investable = true,
            vintage_method = "aggregated",
            profiles = [(2030, ones(6)), (2050, ones(6))],
        ),
        (;
            name = "producer2",
            kind = :producer,
            investable = true,
            vintage_method = "aggregated",
            profiles = [(2030, ones(6)), (2050, ones(6))],
        ),
        (;
            name = "producer3",
            kind = :producer,
            investable = true,
            vintage_method = "compact_profiles",
            profiles = [(2030, ones(6)), (2050, ones(6))],
        ),
    ]
    groups = [
        (;
            name = "group1",
            milestone_year = 2030,
            constraint_sense = "<=",
            rhs = 7700.0,
            invest_method = "use_only_investment_units",
            memberships = [
                (asset = "producer1", coefficient = 3.14),
                (asset = "producer2", coefficient = 6.66),
            ],
        ),
        (;
            name = "group1",
            milestone_year = 2050,
            constraint_sense = ">=",
            rhs = 3300.0,
            invest_method = "use_only_investment_units",
            memberships = [(asset = "producer2", coefficient = 2.51)],
        ),
        (;
            name = "group2",
            milestone_year = 2030,
            constraint_sense = "==",
            rhs = 1234.0,
            invest_method = "use_only_investment_units",
            memberships = [(asset = "producer1", coefficient = 0.73)],
        ),
        (;
            name = "group3",
            milestone_year = 2050,
            constraint_sense = "<=",
            rhs = 987.0,
            invest_method = "use_available_units",
            memberships = [
                (asset = "producer1", coefficient = 2.0),
                (asset = "producer3", coefficient = 4.2),
            ],
        ),
        (;
            name = "group4",
            milestone_year = 2050,
            constraint_sense = "==",
            rhs = 4321.0,
            invest_method = "none",
            memberships = [(asset = "producer2", coefficient = 3.45)],
        ),
    ]
    con, ep = create_investment_group_problem(assets, groups)

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

@testitem "Available-unit group constraints aggregate compact vintages" setup =
    [CommonSetup, ConsInvestmentGroupSetup] tags = [:unit, :constraint, :fast] begin
    assets = [
        (;
            name = "aggregated_asset",
            kind = :producer,
            investable = true,
            vintage_method = "aggregated",
            profiles = [(2050, ones(6))],
        ),
        (;
            name = "compact_asset",
            kind = :producer,
            investable = true,
            vintage_method = "compact_profiles",
            profiles = [(2030, ones(6)), (2050, ones(6))],
        ),
    ]
    groups = [(;
        name = "group1",
        milestone_year = 2050,
        constraint_sense = "<=",
        rhs = 100.0,
        invest_method = "use_available_units",
        memberships = [
            (asset = "aggregated_asset", coefficient = 2.0),
            (asset = "compact_asset", coefficient = 3.0),
        ],
    ),]
    connection, ep = create_investment_group_problem(assets, groups)

    expr_available_asset_units_aggregated =
        ep.expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    expr_available_asset_units_compact =
        ep.expressions[:available_asset_units_compact_vintage_method].expressions[:assets]
    aggregated_ids = [
        row.id for
        row in ep.expressions[:available_asset_units_aggregated_vintage_method].indices if
        row.asset == "aggregated_asset" && row.milestone_year == 2050
    ]
    compact_ids = [
        row.id for
        row in ep.expressions[:available_asset_units_compact_vintage_method].indices if
        row.asset == "compact_asset" && row.milestone_year == 2050
    ]
    observed_constraint = only(_get_cons_object(ep.model, :investment_group))
    expected_constraint = JuMP.@build_constraint(
        sum(2.0 * expr_available_asset_units_aggregated[id] for id in aggregated_ids) +
        sum(3.0 * expr_available_asset_units_compact[id] for id in compact_ids) <= 100.0
    )
    @test _is_constraint_equal(expected_constraint, observed_constraint)
end

@testitem "Available-unit group constraints aggregate only" setup =
    [CommonSetup, ConsInvestmentGroupSetup] tags = [:unit, :constraint, :fast] begin
    assets = [
        (;
            name = "aggregated_asset_1",
            kind = :producer,
            investable = true,
            vintage_method = "aggregated",
            profiles = [(2050, ones(6))],
        ),
        (;
            name = "aggregated_asset_2",
            kind = :producer,
            investable = true,
            vintage_method = "aggregated",
            profiles = [(2050, ones(6))],
        ),
    ]
    groups = [(;
        name = "group1",
        milestone_year = 2050,
        constraint_sense = "<=",
        rhs = 100.0,
        invest_method = "use_available_units",
        memberships = [
            (asset = "aggregated_asset_1", coefficient = 2.0),
            (asset = "aggregated_asset_2", coefficient = 3.0),
        ],
    ),]
    connection, ep = create_investment_group_problem(assets, groups)

    expr_available_asset_units_aggregated =
        ep.expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    aggregated_ids = [
        row.id for
        row in ep.expressions[:available_asset_units_aggregated_vintage_method].indices if
        row.asset in ("aggregated_asset_1", "aggregated_asset_2") && row.milestone_year == 2050
    ]
    observed_constraint = only(_get_cons_object(ep.model, :investment_group))
    expected_constraint = JuMP.@build_constraint(
        sum(2.0 * expr_available_asset_units_aggregated[id] for id in aggregated_ids[1:1]) +
        sum(3.0 * expr_available_asset_units_aggregated[id] for id in aggregated_ids[2:2]) <=
        100.0
    )
    @test _is_constraint_equal(expected_constraint, observed_constraint)
end

@testitem "Available-unit group constraints compact only" setup =
    [CommonSetup, ConsInvestmentGroupSetup] tags = [:unit, :constraint, :fast] begin
    assets = [
        (;
            name = "compact_asset_1",
            kind = :producer,
            investable = true,
            vintage_method = "compact_profiles",
            profiles = [(2030, ones(6))],
        ),
        (;
            name = "compact_asset_2",
            kind = :producer,
            investable = true,
            vintage_method = "compact_profiles",
            profiles = [(2030, ones(6)), (2050, ones(6))],
        ),
    ]
    groups = [(;
        name = "group1",
        milestone_year = 2050,
        constraint_sense = "<=",
        rhs = 100.0,
        invest_method = "use_available_units",
        memberships = [
            (asset = "compact_asset_1", coefficient = 2.0),
            (asset = "compact_asset_2", coefficient = 3.0),
        ],
    ),]
    connection, ep = create_investment_group_problem(assets, groups)

    expr_available_asset_units_compact =
        ep.expressions[:available_asset_units_compact_vintage_method].expressions[:assets]
    group = only(groups)
    expected_terms = [
        membership.coefficient * sum(
            expr_available_asset_units_compact[id] for id in [
                row.id for
                row in ep.expressions[:available_asset_units_compact_vintage_method].indices if
                row.asset == membership.asset && row.milestone_year == group.milestone_year
            ];
            init = 0.0,
        ) for membership in group.memberships
    ]
    observed_constraint = only(_get_cons_object(ep.model, :investment_group))
    expected_constraint = JuMP.@build_constraint(sum(expected_terms; init = 0.0) <= 100.0)
    @test _is_constraint_equal(expected_constraint, observed_constraint)
end
