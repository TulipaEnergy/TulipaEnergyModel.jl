@testset "Test data preparation" begin
    # Description of the test data: One asset with two inputs and two outputs
    # - flow (input_1 -> asset)  with time blocks [1:1, 2:5]
    # - flow (input_2 -> asset)  with time blocks [1:2, 3:5]
    # - flow (asset -> output_1) with time blocks [1:3, 4:5]
    # - flow (asset -> output_2) with time blocks [1:4, 5:5]
    # - asset with time blocks [1:5]
    # - flows relationships:
    #   - INPUT and INPUT:   (input_1 -> asset) and (input_2 -> asset)
    #   - INPUT and OUTPUT:  (input_1 -> asset) and (asset -> output_1)
    #   - OUTPUT and INPUT:  (asset -> output_1) and (input_1 -> asset)
    #   - OUTPUT and OUTPUT: (asset -> output_1) and (asset -> output_2)

    # Setup a temporary DuckDB connection
    connection = DBInterface.connect(DuckDB.DB)

    # Create mock tables for testing using register_data_frame
    flow_time_resolution_rep_period = DataFrame(
        :from_asset =>
            ["input_1", "input_1", "input_2", "input_2", "asset", "asset", "asset", "asset"],
        :to_asset => [
            "asset",
            "asset",
            "asset",
            "asset",
            "output_1",
            "output_1",
            "output_2",
            "output_2",
        ],
        :year => repeat([2025], 8),
        :rep_period => repeat([1], 8),
        :time_block_start => [1, 2, 1, 3, 1, 4, 1, 5],
        :time_block_end => [1, 5, 2, 5, 3, 5, 4, 5],
    )
    DuckDB.register_data_frame(
        connection,
        flow_time_resolution_rep_period,
        "flow_time_resolution_rep_period",
    )

    asset_time_resolution_rep_period = DataFrame(
        :asset => ["asset"],
        :year => [2025],
        :rep_period => [1],
        :time_block_start => [1],
        :time_block_end => [5],
    )
    DuckDB.register_data_frame(
        connection,
        asset_time_resolution_rep_period,
        "asset_time_resolution_rep_period",
    )

    flows_relationships = DataFrame(
        :flow_1_from_asset => ["input_1", "input_1", "asset", "asset"],
        :flow_1_to_asset => ["asset", "asset", "output_1", "output_1"],
        :flow_2_from_asset => ["input_2", "asset", "input_1", "asset"],
        :flow_2_to_asset => ["asset", "output_1", "asset", "output_2"],
        :milestone_year => repeat([2025], 4),
    )
    # We need to register the DataFrame with a name before creating the table
    # because the table is modified (i.e., ALTER statement) in the SQL query
    # to create the merged table.
    DuckDB.register_data_frame(connection, flows_relationships, "flows_relationships_view")
    DuckDB.execute(
        connection,
        "CREATE TABLE flows_relationships AS SELECT * FROM flows_relationships_view",
    )

    rep_periods_data =
        DataFrame(:num_timesteps => [5], :rep_period => [1], :resolution => [1.0], :year => [2025])
    DuckDB.register_data_frame(connection, rep_periods_data, "rep_periods_data")

    @testset "Test create_merge_tables!" begin
        TulipaEnergyModel.create_merged_tables!(connection)

        # Verify the results in the merged tables
        merged_in_flows = TulipaIO.get_table(connection, "merged_in_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 2, 5),
            ("asset", 2025, 1, 1, 2),
            ("asset", 2025, 1, 3, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_in_flows) |> all
        @test DataFrames.nrow(merged_in_flows) == 8
        @test DataFrames.ncol(merged_in_flows) == 5

        merged_out_flows = TulipaIO.get_table(connection, "merged_out_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 4, 5),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 5, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_out_flows) |> all
        @test DataFrames.nrow(merged_out_flows) == 8
        @test DataFrames.ncol(merged_out_flows) == 5

        merged_assets_and_out_flows = TulipaIO.get_table(connection, "merged_assets_and_out_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 4, 5),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 5, 5),
            ("asset", 2025, 1, 1, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_assets_and_out_flows) |> all
        @test DataFrames.nrow(merged_assets_and_out_flows) == 9
        @test DataFrames.ncol(merged_assets_and_out_flows) == 5

        merged_all_flows = TulipaIO.get_table(connection, "merged_all_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 2, 5),
            ("asset", 2025, 1, 1, 2),
            ("asset", 2025, 1, 3, 5),
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 4, 5),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 5, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_all_flows) |> all
        @test DataFrames.nrow(merged_all_flows) == 16
        @test DataFrames.ncol(merged_all_flows) == 5

        merged_all = TulipaIO.get_table(connection, "merged_all")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 2, 5),
            ("asset", 2025, 1, 1, 2),
            ("asset", 2025, 1, 3, 5),
            ("asset", 2025, 1, 1, 3),
            ("asset", 2025, 1, 4, 5),
            ("asset", 2025, 1, 1, 4),
            ("asset", 2025, 1, 5, 5),
            ("asset", 2025, 1, 1, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_all) |> all
        @test DataFrames.nrow(merged_all) == 17
        @test DataFrames.ncol(merged_all) == 5

        merged_flows_relationship = TulipaIO.get_table(connection, "merged_flows_relationship")
        rows_to_test = [
            ("asset_output_1_asset_output_2", 2025, 1, 1, 3),
            ("asset_output_1_asset_output_2", 2025, 1, 4, 5),
            ("asset_output_1_asset_output_2", 2025, 1, 1, 4),
            ("asset_output_1_asset_output_2", 2025, 1, 5, 5),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 3),
            ("asset_output_1_input_1_asset", 2025, 1, 4, 5),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 1),
            ("asset_output_1_input_1_asset", 2025, 1, 2, 5),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 3),
            ("input_1_asset_asset_output_1", 2025, 1, 4, 5),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 1),
            ("input_1_asset_asset_output_1", 2025, 1, 2, 5),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 1),
            ("input_1_asset_input_2_asset", 2025, 1, 2, 5),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 2),
            ("input_1_asset_input_2_asset", 2025, 1, 3, 5),
        ]
        @test _test_rows_exist(rows_to_test, merged_flows_relationship) |> all
        @test DataFrames.nrow(merged_flows_relationship) == 16
        @test DataFrames.ncol(merged_flows_relationship) == 5
    end

    @testset "Test create_lowest_resolution_table!" begin
        TulipaEnergyModel.create_lowest_resolution_table!(connection)

        # Verify the results in the lowest resolution tables
        t_lowest_all = TulipaIO.get_table(connection, "t_lowest_all")
        rows_to_test = [("asset", 2025, 1, 1, 5)]
        @test _test_rows_exist(rows_to_test, t_lowest_all) |> all
        @test DataFrames.nrow(t_lowest_all) == 9
        @test DataFrames.ncol(t_lowest_all) == 5

        t_lowest_all_flows = TulipaIO.get_table(connection, "t_lowest_all_flows")
        rows_to_test = [("asset", 2025, 1, 1, 4), ("asset", 2025, 1, 5, 5)]
        @test _test_rows_exist(rows_to_test, t_lowest_all_flows) |> all
        @test DataFrames.nrow(t_lowest_all_flows) == 10
        @test DataFrames.ncol(t_lowest_all_flows) == 5

        t_lowest_flows_relationship = TulipaIO.get_table(connection, "t_lowest_flows_relationship")
        rows_to_test = [
            ("asset_output_1_asset_output_2", 2025, 1, 1, 4),
            ("asset_output_1_asset_output_2", 2025, 1, 5, 5),
            ("asset_output_1_input_1_asset", 2025, 1, 1, 3),
            ("asset_output_1_input_1_asset", 2025, 1, 4, 5),
            ("input_1_asset_asset_output_1", 2025, 1, 1, 3),
            ("input_1_asset_asset_output_1", 2025, 1, 4, 5),
            ("input_1_asset_input_2_asset", 2025, 1, 1, 2),
            ("input_1_asset_input_2_asset", 2025, 1, 3, 5),
        ]
        @test _test_rows_exist(rows_to_test, t_lowest_flows_relationship) |> all
        @test DataFrames.nrow(t_lowest_flows_relationship) == 8
        @test DataFrames.ncol(t_lowest_flows_relationship) == 5
    end

    @testset "Test create_highest_resolution_table!" begin
        TulipaEnergyModel.create_highest_resolution_table!(connection)

        # Verify the results in the highest resolution tables
        t_highest_all_flows = TulipaIO.get_table(connection, "t_highest_all_flows")
        rows_to_test = [
            ("asset", 2025, 1, 1, 1),
            ("asset", 2025, 1, 2, 2),
            ("asset", 2025, 1, 3, 3),
            ("asset", 2025, 1, 4, 4),
            ("asset", 2025, 1, 5, 5),
        ]
        @test _test_rows_exist(rows_to_test, t_highest_all_flows) |> all
        @test DataFrames.nrow(t_highest_all_flows) == 13
        @test DataFrames.ncol(t_highest_all_flows) == 5

        t_highest_assets_and_out_flows =
            TulipaIO.get_table(connection, "t_highest_assets_and_out_flows")
        rows_to_test =
            [("asset", 2025, 1, 1, 3), ("asset", 2025, 1, 4, 4), ("asset", 2025, 1, 5, 5)]
        @test _test_rows_exist(rows_to_test, t_highest_assets_and_out_flows) |> all
        @test DataFrames.nrow(t_highest_assets_and_out_flows) == 7
        @test DataFrames.ncol(t_highest_assets_and_out_flows) == 5

        t_highest_in_flows = TulipaIO.get_table(connection, "t_highest_in_flows")
        rows_to_test =
            [("asset", 2025, 1, 1, 1), ("asset", 2025, 1, 2, 2), ("asset", 2025, 1, 3, 5)]
        @test _test_rows_exist(rows_to_test, t_highest_in_flows) |> all
        @test DataFrames.nrow(t_highest_in_flows) == 7
        @test DataFrames.ncol(t_highest_in_flows) == 5

        t_highest_out_flows = TulipaIO.get_table(connection, "t_highest_out_flows")
        rows_to_test =
            [("asset", 2025, 1, 1, 3), ("asset", 2025, 1, 4, 4), ("asset", 2025, 1, 5, 5)]
        @test _test_rows_exist(rows_to_test, t_highest_out_flows) |> all
        @test DataFrames.nrow(t_highest_out_flows) == 7
        @test DataFrames.ncol(t_highest_out_flows) == 5
    end

    # test that the final number of tables is correct
    @test DataFrames.nrow(TulipaIO.show_tables(connection)) == 18
end
