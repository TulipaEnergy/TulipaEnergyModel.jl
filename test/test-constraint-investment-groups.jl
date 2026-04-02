@testsnippet ConsInvestmentGroupSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_investment_group_problem()
        tulipa = TB.TulipaData()

        TB.add_asset!(
            tulipa,
            "producer1",
            :producer;
            investable = true,
            investment_method = "simple",
        )
        TB.add_asset!(
            tulipa,
            "producer2",
            :producer;
            investable = true,
            investment_method = "simple",
        )
        TB.attach_profile!(tulipa, "producer1", :availability, 2030, ones(6))
        TB.attach_profile!(tulipa, "producer2", :availability, 2050, ones(6))

        connection = TB.create_connection(tulipa, TEM.schema)

        # There is no way to inform these via TB yet
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE group_asset (name VARCHAR, milestone_year INT, constraint_sense VARCHAR, rhs DOUBLE, invest_method BOOL);
            INSERT INTO group_asset VALUES ('group1', 2030, '<=', 7700, true);
            INSERT INTO group_asset VALUES ('group1', 2050, '>=', 3300, true);
            INSERT INTO group_asset VALUES ('group2', 2030, '==', 1234, true);
            INSERT INTO group_asset VALUES ('group2', 2050, '==', 4321, false);
            """,
        )
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE group_asset_membership (group_name VARCHAR, milestone_year INT, asset VARCHAR, coefficient DOUBLE);
            INSERT INTO group_asset_membership VALUES ('group1', 2030, 'producer1', 3.14);
            INSERT INTO group_asset_membership VALUES ('group1', 2030, 'producer2', 6.66);
            INSERT INTO group_asset_membership VALUES ('group1', 2050, 'producer2', 2.51);
            INSERT INTO group_asset_membership VALUES ('group2', 2030, 'producer1', 0.73);
            INSERT INTO group_asset_membership VALUES ('group2', 2050, 'producer2', 3.45);
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
    [:unit, :constraint] begin
    con, ep = create_investment_group_problem()

    var_assets_investment = ep.variables[:assets_investment].container
    var_lookup = Dict(
        (row.asset, row.milestone_year) => var_assets_investment[row.id] for
        row in ep.variables[:assets_investment].indices
    )

    # :group_investment
    expected_cons_lookup = Dict(
        ("group1", 2030) => JuMP.@build_constraint(
            var_lookup["producer1", 2030] * 3.14 + var_lookup["producer2", 2030] * 6.66 <= 7700
        ),
        ("group1", 2050) =>
            JuMP.@build_constraint(var_lookup["producer2", 2050] * 2.51 >= 3300),
        ("group2", 2030) =>
            JuMP.@build_constraint(var_lookup["producer1", 2030] * 0.73 == 1234),
        # No group4, because invest_method is false
    )
    observed_cons = _get_cons_object(ep.model, :investment_group)
    observed_cons_lookup = Dict(
        (row.name, row.milestone_year) => observed_cons[row.id] for
        row in DuckDB.query(con, "FROM cons_group_investment")
    )
    for ((group_name, milestone_year), observed_cons) in observed_cons_lookup
        @test _is_constraint_equal(expected_cons_lookup[group_name, milestone_year], observed_cons)
    end
end
