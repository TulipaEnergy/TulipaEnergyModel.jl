@testsnippet ConsInvestmentGroupSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    struct ConsInvestmentGroupData end

    function create_investment_group_problem(config::ConsInvestmentGroupData;)
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

        connection = TB.create_connection(tulipa, TEM.schema)

        # There is no way to inform these via TB yet
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE group_asset (name VARCHAR, milestone_year INT, max_investment_limit DOUBLE, invest_method BOOL, min_investment_limit DOUBLE);
            INSERT INTO group_asset VALUES ('group1', 2030, 7700, true, 0.0);
            INSERT INTO group_asset VALUES ('group2', 2030, 3300, true, 0.0);
            """,
        )
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE group_asset_membership (group_name VARCHAR, asset VARCHAR, coefficient DOUBLE);
            INSERT INTO group_asset_membership VALUES ('group1', 'producer1', 3.14);
            INSERT INTO group_asset_membership VALUES ('group1', 'producer2', 6.66);
            INSERT INTO group_asset_membership VALUES ('group2', 'producer2', 2.51);
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
    con, ep = create_investment_group_problem(ConsInvestmentGroupData())

    var_assets_investment = ep.variables[:assets_investment].container
    var_lookup = Dict(
        row.asset => var_assets_investment[row.id] for
        row in ep.variables[:assets_investment].indices
    )

    # :group_max_investment_limit
    expected_cons_lookup = Dict(
        "group1" => JuMP.@build_constraint(
            var_lookup["producer1"] * 3.14 + var_lookup["producer2"] * 6.66 <= 7700
        ),
        "group2" => JuMP.@build_constraint(var_lookup["producer2"] * 2.51 <= 3300),
    )
    observed_cons = _get_cons_object(ep.model, :investment_group_max_limit)
    observed_cons_lookup = Dict(
        row.name => observed_cons[row.id] for
        row in DuckDB.query(con, "FROM cons_group_max_investment_limit")
    )
    @test _is_constraint_equal(expected_cons_lookup["group1"], observed_cons_lookup["group1"])
    @test _is_constraint_equal(expected_cons_lookup["group2"], observed_cons_lookup["group2"])
end
