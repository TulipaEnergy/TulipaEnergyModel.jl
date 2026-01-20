@testitem "Commodity price is used correctly" setup = [CommonSetup] tags = [:case_study, :slow] begin
    dir = joinpath(INPUT_FOLDER, "MIMO")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)

    TulipaEnergyModel.populate_with_defaults!(connection)

    # Copied over from test-case-studies.jl
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 89360.638146 atol = 1e-5

    # Changing commodity_price to make sure it makes a difference
    DuckDB.query(
        connection,
        """
        UPDATE flow_milestone
            SET commodity_price = 10.0
            WHERE from_asset = 'biomass'
        """,
    )
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 89971.40505 atol = 1e-5

    # Testing commodity_price profile
    # We duplicate the biomass_profile replacing the value
    DuckDB.query(
        connection,
        """
        WITH cte_one_profile AS (
            SELECT
                profiles_rep_periods.* EXCLUDE (profile_name, value)
            FROM profiles_rep_periods
            WHERE profile_name = 'biomass_profile'
        )
        INSERT INTO profiles_rep_periods BY NAME
            SELECT
                'commodity_price' AS profile_name,
                0.1 AS value,
                cte_one_profile.*,
            FROM cte_one_profile
        """,
    )
    # Now we assign it to a flow
    DuckDB.query(
        connection,
        """
        INSERT INTO flows_profiles (from_asset, to_asset, year, profile_type, profile_name)
            VALUES ('biomass', 'power_plant', 2030, 'commodity_price', 'commodity_price');
        """,
    )

    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 89421.71484 atol = 1e-5
end

@testitem "Commodity price part of flows_operational_cost is correct" tags = [:unit, :objective] setup =
    [CommonSetup] begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC
    using Statistics

    commodity_price = 3.14
    commodity_price_profile = collect(1.0:6.0)

    function full_run(; add_commodity_price, add_commodity_price_profile)
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "Producer", :producer)
        TB.add_asset!(tulipa, "Consumer", :consumer)
        if add_commodity_price
            TB.add_flow!(tulipa, "Producer", "Consumer"; commodity_price)
        else
            TB.add_flow!(tulipa, "Producer", "Consumer")
        end
        if add_commodity_price_profile
            TB.attach_profile!(
                tulipa,
                "Producer",
                "Consumer",
                :commodity_price,
                2030,
                commodity_price_profile,
            )
        else
            TB.attach_profile!(
                tulipa,
                "Producer",
                :availability,
                2030,
                zeros(length(commodity_price_profile)),
            )  # At least one profile is necessary (Maybe TulipaBuilder should allow it?)
        end
        TB.set_partition!(tulipa, "Producer", "Consumer", 2030, 1, "explicit", "1;2;3")

        connection = TB.create_connection(tulipa)
        TC.dummy_cluster!(connection)
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        var_flow = energy_problem.variables[:flow]
        partitions =
            Dict(row.id => row.time_block_start:row.time_block_end for row in var_flow.indices)
        flow_lookup = Dict(row.id => var_flow.container[row.id] for row in var_flow.indices)
        observed = energy_problem.model[:flows_operational_cost]

        return energy_problem, var_flow, partitions, flow_lookup, observed
    end

    # Without commodity_price
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = false, add_commodity_price_profile = false)
    expected = JuMP.AffExpr(0.0)
    @test expected == observed

    # Traditional commodity_price
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = true, add_commodity_price_profile = false)
    expected = sum(flow_lookup[i] * commodity_price for i in keys(partitions))
    @test expected == observed

    # Profile only, (default commodity_price = 0.0)
    @test_throws TEM.DataValidationException full_run(
        add_commodity_price = false,
        add_commodity_price_profile = true,
    )

    # Profile and commodity_price = 3.14
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = true, add_commodity_price_profile = true)
    expected = sum(
        flow_lookup[i] * commodity_price * Statistics.mean(commodity_price_profile[partitions[i]]) for i in keys(partitions)
    )

    @test expected == observed
end
