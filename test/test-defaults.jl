@testitem "Test populate_with_defaults! from basic data" setup = [CommonSetup, TestData] tags =
    [:unit, :validation, :fast] begin
    # Most basic version of data
    connection = _create_connection_from_dict(TestData.simplest_data)

    # Test that it fails
    @test_throws TulipaEnergyModel.DataValidationException TulipaEnergyModel.EnergyProblem(
        connection,
    )

    # Fix missing columns
    TulipaEnergyModel.populate_with_defaults!(connection)

    # Test that it doesn't fail
    TulipaEnergyModel.EnergyProblem(connection)
end

@testitem "Test inter-period storage-level bounds default" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(connection, "ALTER TABLE asset DROP COLUMN inter_period_storage_level_bounds")

    TEM.populate_with_defaults!(connection)

    values = [
        row.inter_period_storage_level_bounds for row in
        DuckDB.query(connection, "SELECT DISTINCT inter_period_storage_level_bounds FROM asset")
    ]
    @test values == ["inter_period_only"]
end

@testitem "Test Tiny fixture has all defaults and populate doesn't break it" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()

    asset_capacity = Dict(
        row.asset => row.capacity for
        row in DuckDB.query(connection, "SELECT asset.asset, asset.capacity FROM asset")
    )

    # Test that it doesn't fail
    TulipaEnergyModel.EnergyProblem(connection)

    # This should not change anything
    TulipaEnergyModel.populate_with_defaults!(connection)

    for row in DuckDB.query(connection, "SELECT asset.asset, asset.capacity FROM asset")
        @test row.capacity == asset_capacity[row.asset]
    end
end

@testitem "Test populate_with_defaults preserves extra columns" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()

    DuckDB.query(connection, "ALTER TABLE asset ADD COLUMN extra INTEGER")

    TulipaEnergyModel.populate_with_defaults!(connection)

    # Make sure that there is one (and only one) column `extra` in `asset`
    @test TulipaEnergyModel.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(
            connection,
            "SELECT COUNT(*) FROM duckdb_columns() WHERE table_name = 'asset' AND column_name = 'extra'",
        ),
    ) == 1
end

@testitem "Test populate_with_defaults adds investment and available units limits" setup =
    [CommonSetup] tags = [:unit, :validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        ALTER TABLE asset_commission DROP COLUMN investment_min_limit;
        ALTER TABLE asset_commission DROP COLUMN investment_min_limit_storage_energy;
        ALTER TABLE asset_milestone DROP COLUMN min_available_units;
        ALTER TABLE asset_milestone DROP COLUMN max_available_units;
        """,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)

    @test all(
        row.investment_min_limit == 0 for
        row in DuckDB.query(connection, "SELECT investment_min_limit FROM asset_commission")
    )
    @test all(
        row.investment_min_limit_storage_energy == 0 for row in
        DuckDB.query(connection, "SELECT investment_min_limit_storage_energy FROM asset_commission")
    )
    @test all(
        ismissing(row.min_available_units) && ismissing(row.max_available_units) for
        row in DuckDB.query(
            connection,
            "SELECT min_available_units, max_available_units FROM asset_milestone",
        )
    )
end

@testitem "Test populate_with_defaults fixes missing columns" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()

    # Remove a column from asset
    DuckDB.query(
        connection,
        "ALTER TABLE asset
        DROP COLUMN capacity
        ",
    )

    # Test that it fails
    @test_throws TulipaEnergyModel.DataValidationException TulipaEnergyModel.EnergyProblem(
        connection,
    )

    # Fix missing columns
    TulipaEnergyModel.populate_with_defaults!(connection)

    for row in DuckDB.query(connection, "SELECT asset.asset, asset.capacity FROM asset")
        @test row.capacity == TulipaEnergyModel.schema["asset"]["capacity"]["default"]
    end

    # Test that it doesn't fail
    TulipaEnergyModel.EnergyProblem(connection)
end

@testitem "Test populate_with_defaults fixes column type" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _storage_fixture()

    # Drop partition with correct type
    DuckDB.query(
        connection,
        "ALTER TABLE assets_rep_periods_partitions
        DROP COLUMN partition
        ",
    )

    # Add partition column with integer type
    DuckDB.query(
        connection,
        "ALTER TABLE assets_rep_periods_partitions
        ADD COLUMN partition INTEGER DEFAULT 1
        ",
    )

    # Fix columns
    TulipaEnergyModel.populate_with_defaults!(connection)

    type_of_partition_column =
        TulipaEnergyModel.get_single_element_from_query_and_ensure_its_only_one(
            DuckDB.query(
                connection,
                "SELECT data_type
                FROM duckdb_columns()
                WHERE table_name = 'assets_rep_periods_partitions'
                    AND column_name = 'partition'
                ",
            ),
        )
    @test type_of_partition_column == "VARCHAR"
end

@testitem "Test populate_with_defaults fills NULL values with defaults" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()

    # Drop column capacity
    DuckDB.query(
        connection,
        "ALTER TABLE asset
        DROP COLUMN capacity
        ",
    )

    # Add capacity back with some missing values (don't inform a default)
    DuckDB.query(
        connection,
        "ALTER TABLE asset
        ADD COLUMN capacity DOUBLE
        ",
    )
    # Fill some values of capacity with non-default values
    DuckDB.query(connection, "UPDATE asset SET capacity = if(len(asset) > 4, 5.0, NULL)")

    unique_capacity =
        unique([row.capacity for row in DuckDB.query(connection, "SELECT capacity FROM asset")])
    @test any(ismissing.(unique_capacity))  # One element is missing
    @test 5.0 in unique_capacity            # One element is a 5.0
    @test length(unique_capacity) == 2      # Two elements in total

    TulipaEnergyModel.populate_with_defaults!(connection)

    unique_capacity =
        unique([row.capacity for row in DuckDB.query(connection, "SELECT capacity FROM asset")])
    @test 0.0 in unique_capacity            # One element is 0.0
    @test 5.0 in unique_capacity            # One element is a 5.0
    @test length(unique_capacity) == 2      # Two elements in total
end

@testitem "Test populate_with_defaults fails on missing required columns" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _tiny_fixture()

    # Remove a primary key from asset
    DuckDB.query(
        connection,
        "ALTER TABLE asset_milestone
        DROP COLUMN milestone_year
        ",
    )

    # Test that it fails
    @test_throws TulipaEnergyModel.DataValidationException TulipaEnergyModel.EnergyProblem(
        connection,
    )

    # Fail to fix missing columns
    @test_throws TulipaEnergyModel.DataValidationException TulipaEnergyModel.populate_with_defaults!(
        connection,
    )
end
