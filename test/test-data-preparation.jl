@testset "Test creating tables for lowest and highest resolution in different cases" begin
    # Setup a temporary DuckDB connection
    connection = DuckDB.DB()

    try
        # Create mock tables for testing
        DBInterface.execute(
            connection,
            "CREATE TABLE flow_time_resolution_rep_period
                (from_asset STRING,
                 to_asset STRING,
                 year INTEGER,
                 rep_period INTEGER,
                 time_block_start INTEGER,
                 time_block_end INTEGER)
            ",
        )
        DBInterface.execute(
            connection,
            "CREATE TABLE asset_time_resolution_rep_period
                (asset STRING,
                 year INTEGER,
                 rep_period INTEGER,
                 time_block_start INTEGER,
                 time_block_end INTEGER)
            ",
        )
        DBInterface.execute(
            connection,
            "CREATE TABLE flows_relationships
                (flow_1_from_asset STRING,
                 flow_1_to_asset STRING,
                 flow_2_from_asset STRING,
                 flow_2_to_asset STRING,
                 milestone_year INTEGER)
            ",
        )

        DBInterface.execute(
            connection,
            "CREATE TABLE rep_periods_data
                (num_timesteps INTEGER,
                 rep_period INTEGER,
                 resolution DOUBLE,
                 year INTEGER)
            ",
        )

        # Insert mock data into the tables (example data of a Multiple Inputs and Outputs - MIMO)
        DBInterface.execute(
            connection,
            "INSERT INTO flow_time_resolution_rep_period
                 VALUES ('input_1', 'asset', 2025, 1, 1, 1),
                        ('input_2', 'asset', 2025, 1, 1, 2),
                        ('asset', 'output_1', 2025, 1, 1, 3),
                        ('asset', 'output_2', 2025, 1, 1, 4)
            ",
        )
        DBInterface.execute(
            connection,
            "INSERT INTO asset_time_resolution_rep_period VALUES ('asset', 2025, 1, 1, 5)",
        )
        DBInterface.execute(
            connection,
            "INSERT INTO flows_relationships
                VALUES ('input_1', 'asset', 'input_2', 'asset', 2025),
                       ('input_1', 'asset', 'asset', 'output_1', 2025),
                       ('asset', 'output_1', 'input_1', 'asset', 2025),
                       ('asset', 'output_1', 'asset', 'output_2', 2025),
            ",
        )
        DBInterface.execute(
            connection,
            "INSERT INTO rep_periods_data
                VALUES (5, 1, 1.0, 2025)
            ",
        )

        # Call the create_merge_tables! function to test
        TulipaEnergyModel.create_merged_tables!(connection)

        # Verify the results in the merged tables
        merged_in_flows = TulipaIO.get_table(connection, "merged_in_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 1, 2),
            ("output_1", 2025, 1, 1, 3),
            ("output_2", 2025, 1, 1, 4),
        ]
        @test _test_rows_exist(rows_to_test, merged_in_flows) |> all

        merged_out_flows = TulipaIO.get_table(connection, "merged_out_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 1, 4),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
        ]
        @test _test_rows_exist(rows_to_test, merged_out_flows) |> all

        merged_assets_and_out_flows = TulipaIO.get_table(connection, "merged_assets_and_out_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 1, 5),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
        ]
        @test _test_rows_exist(rows_to_test, merged_assets_and_out_flows) |> all

        merged_all_flows = TulipaIO.get_table(connection, "merged_all_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 1, 2),
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 1, 4),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
            ("output_1", 2025, 1, 1, 3),
            ("output_2", 2025, 1, 1, 4),
        ]
        @test _test_rows_exist(rows_to_test, merged_all_flows) |> all

        merged_all = TulipaIO.get_table(connection, "merged_all")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 1, 2),
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 1, 5),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
            ("output_1", 2025, 1, 1, 3),
            ("output_2", 2025, 1, 1, 4),
        ]
        @test _test_rows_exist(rows_to_test, merged_all) |> all

        merged_flows_relationship = TulipaIO.get_table(connection, "merged_flows_relationship")
        rows_to_test = [
            ("asset_output_1_asset_output_2", 2025, 1, 1, 3),
            ("asset_output_1_asset_output_2", 2025, 1, 1, 4),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 1),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 3),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 1),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 3),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 1),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 2),
        ]
        @test _test_rows_exist(rows_to_test, merged_flows_relationship) |> all

        # Call the create_lowest_resolution_table! function to test
        TulipaEnergyModel.create_lowest_resolution_table!(connection)

        # Verify the results in the lowest resolution tables
        t_lowest_all = TulipaIO.get_table(connection, "t_lowest_all")
        rows_to_test = [
            ("asset", 2025, 1, 1, 5),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
            ("output_1", 2025, 1, 1, 3),
            ("output_2", 2025, 1, 1, 4),
        ]
        @test _test_rows_exist(rows_to_test, t_lowest_all) |> all

        t_lowest_all_flows = TulipaIO.get_table(connection, "t_lowest_all_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 4),
            ("input_1", 2025, 1, 1, 1),
            ("input_2", 2025, 1, 1, 2),
            ("output_1", 2025, 1, 1, 3),
            ("output_2", 2025, 1, 1, 4),
        ]
        @test _test_rows_exist(rows_to_test, t_lowest_all_flows) |> all

        t_lowest_flows_relationship = TulipaIO.get_table(connection, "t_lowest_flows_relationship")
        rows_to_test = [
            ("asset_output_1_asset_output_2", 2025, 1, 1, 4),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 3),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 3),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 2),
        ]
        @test _test_rows_exist(rows_to_test, t_lowest_flows_relationship) |> all

        # Call the create_lowest_resolution_table! function to test
        TulipaEnergyModel.create_highest_resolution_table!(connection)

        # test that the final number of tables is correct
        @test DataFrames.nrow(TulipaIO.show_tables(connection)) == 17

    finally
        # Clean up the temporary database
        DBInterface.execute(connection, "DROP TABLE IF EXISTS flow_time_resolution_rep_period")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS asset_time_resolution_rep_period")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS flows_relationships")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS rep_periods_data")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_in_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_out_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_assets_and_out_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_all_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_all")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_flows_relationship")
        DuckDB.close(connection)
    end
end
