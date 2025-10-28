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
