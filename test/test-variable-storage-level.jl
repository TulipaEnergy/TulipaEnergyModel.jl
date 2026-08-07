@testitem "Create variables for storage levels from test case" setup = [CommonSetup] tags =
    [:unit, :fast, :variable] begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    # We use Norse dataset since it has both seasonal and non-seasonal storage,
    # as well as initial storage levels with missing values and without missing (and greater than 0),
    # which allows us to test the creation of the storage level variables and their properties in one test case for all the cases.
    # non seasonal
    # - Midgard_PHS -> initial_storage_level = missing
    # - Asgard_Battery -> initial_storage_level = 1.0 (note: we update this value from missing to 1.0 in the test to cover the edge case of initial storage level greater than 0)
    # seasonal
    # - Valhalla_H2_storage -> initial_storage_level = missing
    # - Midgard_Hydro -> initial_storage_level = 0.5

    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    # we need to update the initial_storage_level of the Asgard_Battery to 1.0 to test all the edge cases
    DuckDB.query(
        connection,
        "UPDATE asset_milestone SET initial_storage_level = 1.0 WHERE asset = 'Asgard_Battery' AND milestone_year = 2030",
    )
    # we update the partitions files to specification uniform and partition 1
    # to simplify the test and avoid testing the partitioning logic in this test
    DuckDB.query(
        connection,
        "UPDATE assets_rep_periods_partitions SET specification = 'uniform', partition = 1",
    )
    DuckDB.query(
        connection,
        "UPDATE assets_timeframe_partitions SET specification = 'uniform', partition = 1",
    )
    DuckDB.query(
        connection,
        "UPDATE flows_rep_periods_partitions SET specification = 'uniform', partition = 1",
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    # get the rep periods data to compute the expected number of variables
    rep_periods_data = DuckDB.query(connection, "SELECT * FROM rep_periods_data") |> DataFrame
    expected_num_storage_level_intra_rep_period_vars =
        expected_num_accumulated_storage_level_intra_rep_period_vars =
            sum(rep_periods_data.num_timesteps)
    num_rep_periods = DataFrames.nrow(rep_periods_data)

    # get the periods data to compute the expected number of variables
    periods_data = DuckDB.query(connection, "SELECT * FROM timeframe_data") |> DataFrame
    expected_num_storage_level_inter_period_vars = length(periods_data.period)

    # Test storage level rep-period variable only for the Midgard_PHS and Asgard_Battery assets
    # since use_inter_period_constraints = false in the test case
    @test haskey(energy_problem.variables, :storage_level_intra_rep_period)
    storage_level_intra_rep_period =
        energy_problem.variables[:storage_level_intra_rep_period].container
    @test length(storage_level_intra_rep_period) ==
          2 * expected_num_storage_level_intra_rep_period_vars
    # get the variable indices
    storage_level_intra_rep_period_indices =
        energy_problem.variables[:storage_level_intra_rep_period].indices |> DataFrame
    # only the assets Midgard_PHS and Asgard_Battery should be in the indices
    non_seasonal_assets = storage_level_intra_rep_period_indices.asset |> unique |> sort
    @test non_seasonal_assets == ["Asgard_Battery", "Midgard_PHS"]
    # group the indices by asset, milestone_year and rep_period
    grouped_indices = DataFrames.groupby(
        storage_level_intra_rep_period_indices,
        [:asset, :milestone_year, :rep_period],
    )
    @test grouped_indices.ngroups == num_rep_periods * 2 # we have 2 assets with non-seasonal storage, so we expect 2 groups per rep period (only 1 year)
    # Initial levels are enforced by explicit constraints because the available capacity can
    # contain investment variables. All storage-level variables keep their zero lower bound.
    for group in grouped_indices
        for id in group.id
            _test_variable_properties(storage_level_intra_rep_period[id], 0.0, nothing)
        end
    end
    @test length(energy_problem.model[:cycling_condition_intra_rep_period]) == num_rep_periods

    # Test storage level inter-period variable only for the Valhalla_H2_storage and Midgard_Hydro asset
    # since it is the only seasonal storage in the test case
    @test haskey(energy_problem.variables, :storage_level_inter_period)
    storage_level_inter_period = energy_problem.variables[:storage_level_inter_period].container
    @test length(storage_level_inter_period) == 2 * expected_num_storage_level_inter_period_vars
    # get the variable indices
    storage_level_inter_period_indices =
        energy_problem.variables[:storage_level_inter_period].indices |> DataFrame
    # only the assets Valhalla_H2_storage and Midgard_Hydro should be in the indices
    seasonal_assets = storage_level_inter_period_indices.asset |> unique |> sort
    @test seasonal_assets == ["Midgard_Hydro", "Valhalla_H2_storage"]
    # group the indices by asset and milestone_year
    grouped_indices =
        DataFrames.groupby(storage_level_inter_period_indices, [:asset, :milestone_year])
    @test grouped_indices.ngroups == 2 # we have 2 assets with seasonal storage, so we expect 2 groups (only 1 year)
    for group in grouped_indices
        for id in group.id
            _test_variable_properties(storage_level_inter_period[id], 0.0, nothing)
        end
    end
    @test length(energy_problem.model[:cycling_condition_inter_period]) == 1

    ## Test accumulated storage level intra-period variable only for the Valhalla_H2_storage and Midgard_Hydro asset
    # since it is the only seasonal storage in the test case
    @test haskey(energy_problem.variables, :accumulated_storage_level_intra_rep_period)
    accumulated_storage_level_intra_rep_period =
        energy_problem.variables[:accumulated_storage_level_intra_rep_period].container
    # get the variable indices
    accumulated_storage_level_intra_rep_period_indices =
        energy_problem.variables[:accumulated_storage_level_intra_rep_period].indices |> DataFrame
    # only the assets Valhalla_H2_storage and Midgard_Hydro should be in the indices
    seasonal_assets = accumulated_storage_level_intra_rep_period_indices.asset |> unique |> sort
    @test seasonal_assets == ["Midgard_Hydro", "Valhalla_H2_storage"]
    # group the indices by asset, milestone_year and rep_period
    grouped_indices = DataFrames.groupby(
        accumulated_storage_level_intra_rep_period_indices,
        [:asset, :milestone_year, :rep_period],
    )
    @test grouped_indices.ngroups == num_rep_periods * 2 # we have 2 assets with seasonal storage, so we expect 2 groups per rep period (only 1 year)
    # This expression variable is free and has no bounds.
    for group in grouped_indices
        for id in group.id
            var = accumulated_storage_level_intra_rep_period[id]
            _test_variable_properties(var, nothing, nothing)
        end
    end
end
