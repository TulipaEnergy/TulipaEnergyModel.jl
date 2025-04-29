@testset "create_merged_tables!" begin
    # Setup a temporary DuckDB connection
    connection = DuckDB.DB()

    try
        # Create mock tables for testing
        DBInterface.execute(
            connection,
            "CREATE TABLE flow_time_resolution_rep_period
                (from_asset STRING,
                 to_asset STRING,
                 year INT,
                 rep_period INT,
                 time_block_start INT,
                 time_block_end INT)
            ",
        )
        DBInterface.execute(
            connection,
            "CREATE TABLE asset_time_resolution_rep_period
                (asset STRING,
                 year INT,
                 rep_period INT,
                 time_block_start INT,
                 time_block_end INT)
            ",
        )
        DBInterface.execute(
            connection,
            "CREATE TABLE flows_relationships
                (flow_1_from_asset STRING,
                 flow_1_to_asset STRING,
                 flow_2_from_asset STRING,
                 flow_2_to_asset STRING,
                 milestone_year INT)
            ",
        )

        # Insert mock data into the tables
        DBInterface.execute(
            connection,
            "INSERT INTO flow_time_resolution_rep_period
                 VALUES ('input_1', 'asset', 2025, 1, 1, 3),
                        ('input_2', 'asset', 2025, 1, 1, 2),
                        ('asset', 'output_1', 2025, 1, 1, 1),
                        ('asset', 'output_2', 2025, 1, 1, 2)
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

        # Call the function to test
        TulipaEnergyModel.create_merged_tables!(connection)

        # Verify the results in the merged tables
        merged_in_flows = TulipaIO.get_table(connection, "merged_in_flows")
        @test DataFrames.nrow(merged_in_flows) == 4
        @test DataFrames.ncol(merged_in_flows) == 5
        @test issubset(merged_in_flows.asset, ["asset" "output_1" "output_2"])

        merged_out_flows = TulipaIO.get_table(connection, "merged_out_flows")
        @test DataFrames.nrow(merged_out_flows) == 4
        @test DataFrames.ncol(merged_out_flows) == 5
        @test issubset(merged_out_flows.asset, ["asset" "input_1" "input_2"])

        merged_assets_and_out_flows = TulipaIO.get_table(connection, "merged_assets_and_out_flows")
        @test DataFrames.nrow(merged_assets_and_out_flows) == 5
        @test DataFrames.ncol(merged_assets_and_out_flows) == 5
        @test issubset(merged_assets_and_out_flows.asset, ["asset" "input_1" "input_2"])

        merged_all_flows = TulipaIO.get_table(connection, "merged_all_flows")
        @test DataFrames.nrow(merged_all_flows) == 7
        @test DataFrames.ncol(merged_all_flows) == 5
        @test issubset(merged_all_flows.asset, ["asset" "input_1" "input_2" "output_1" "output_2"])

        merged_all = TulipaIO.get_table(connection, "merged_all")
        @test DataFrames.nrow(merged_all) == 8
        @test DataFrames.ncol(merged_all) == 5
        @test issubset(merged_all.asset, ["asset" "input_1" "input_2" "output_1" "output_2"])

        merged_flows_relationship = TulipaIO.get_table(connection, "merged_flows_relationship")
        @test DataFrames.nrow(merged_flows_relationship) == 3
        @test DataFrames.ncol(merged_flows_relationship) == 5
        @test unique(merged_flows_relationship.asset) == ["asset"]

    finally
        # Clean up the temporary database
        DBInterface.execute(connection, "DROP TABLE IF EXISTS flow_time_resolution_rep_period")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS asset_time_resolution_rep_period")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS flows_relationships")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_in_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_out_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_assets_and_out_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_all_flows")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_all")
        DBInterface.execute(connection, "DROP TABLE IF EXISTS merged_flows_relationship")
        DuckDB.close(connection)
    end
end
