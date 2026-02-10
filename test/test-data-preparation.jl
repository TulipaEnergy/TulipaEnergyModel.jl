@testsnippet DataPreparationSetup begin
    # Description of the test data: One energy asset, the "death_star", with two inputs and two outputs
    # - flow (input_1 -> death_star)  with time blocks [1:1, 2:5]
    # - flow (input_2 -> death_star)  with time blocks [1:2, 3:5]
    # - flow (death_star -> output_1) with time blocks [1:3, 4:5]
    # - flow (death_star -> output_2) with time blocks [1:4, 5:5]
    # - death_star with time blocks [1:5]
    # - flows relationships:
    #   - INPUT and INPUT:   (input_1 -> death_star) and (input_2 -> death_star)
    #   - INPUT and OUTPUT:  (input_1 -> death_star) and (death_star -> output_1)
    #   - OUTPUT and INPUT:  (death_star -> output_1) and (input_1 -> death_star)
    #   - OUTPUT and OUTPUT: (death_star -> output_1) and (death_star -> output_2)

    # Setup a temporary DuckDB connection
    connection = DBInterface.connect(DuckDB.DB)

    # Create mock tables for testing using register_data_frame
    table_rows = [("death_star", "conversion")]
    asset = DataFrame(table_rows, [:asset, :type])
    DuckDB.register_data_frame(connection, asset, "asset")
    year = Int32(2025)
    rp = Int32(1)

    table_rows = [("input_1", "death_star", year, true), ("input_2", "death_star", year, false)]
    flow_milestone = DataFrame(table_rows, [:from_asset, :to_asset, :milestone_year, :dc_opf])
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")

    table_rows = [
        ("input_1", "death_star", year, 1.0),
        ("input_2", "death_star", year, 0.0),
        ("death_star", "output_1", year, 1.0),
        ("death_star", "output_2", year, 0.0),
    ]
    flow_commission =
        DataFrame(table_rows, [:from_asset, :to_asset, :commission_year, :conversion_coefficient])
    DuckDB.register_data_frame(connection, flow_commission, "flow_commission")

    table_rows = [
        ("input_1", "death_star", year, rp, Int32(1), Int32(1)),
        ("input_1", "death_star", year, rp, Int32(2), Int32(5)),
        ("input_2", "death_star", year, rp, Int32(1), Int32(2)),
        ("input_2", "death_star", year, rp, Int32(3), Int32(5)),
        ("death_star", "output_1", year, rp, Int32(1), Int32(3)),
        ("death_star", "output_1", year, rp, Int32(4), Int32(5)),
        ("death_star", "output_2", year, rp, Int32(1), Int32(4)),
        ("death_star", "output_2", year, rp, Int32(5), Int32(5)),
    ]
    flow_time_resolution_rep_period = DataFrame(
        table_rows,
        [:from_asset, :to_asset, :year, :rep_period, :time_block_start, :time_block_end],
    )
    DuckDB.register_data_frame(
        connection,
        flow_time_resolution_rep_period,
        "flow_time_resolution_rep_period",
    )

    table_rows = [
        ("input_1", year, rp, Int32(1), Int32(3)),
        ("input_1", year, rp, Int32(4), Int32(5)),
        ("death_star", year, rp, Int32(1), Int32(5)),
    ]
    asset_time_resolution_rep_period =
        DataFrame(table_rows, [:asset, :year, :rep_period, :time_block_start, :time_block_end])
    DuckDB.register_data_frame(
        connection,
        asset_time_resolution_rep_period,
        "asset_time_resolution_rep_period",
    )

    table_rows = [
        ("input_1", "death_star", "input_2", "death_star", year),
        ("input_1", "death_star", "death_star", "output_1", year),
        ("death_star", "output_1", "input_1", "death_star", year),
        ("death_star", "output_1", "death_star", "output_2", year),
    ]
    flows_relationships = DataFrame(
        table_rows,
        [
            :flow_1_from_asset,
            :flow_1_to_asset,
            :flow_2_from_asset,
            :flow_2_to_asset,
            :milestone_year,
        ],
    )
    DuckDB.register_data_frame(connection, flows_relationships, "flows_relationships")

    table_rows = [(5, rp, 1.0, year)]
    rep_periods_data = DataFrame(table_rows, [:num_timesteps, :rep_period, :resolution, :year])
    DuckDB.register_data_frame(connection, rep_periods_data, "rep_periods_data")

    # Auxiliary information for the tests
    expected_cols = [:asset, :year, :rep_period, :time_block_start, :time_block_end]
    where_ = "asset LIKE '%death_star%' ORDER BY asset, rep_period, time_block_start, time_block_end"
end

@testitem "Test create_merged_tables!" setup = [CommonSetup, DataPreparationSetup] tags =
    [:unit, :data_preparation, :fast] begin
    TulipaEnergyModel.create_merged_tables!(connection)

    # Verify the results in the merged tables
    merged_in_flows = TulipaIO.select_tbl(connection, "merged_in_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 1, 2),
        ("death_star", 2025, 1, 2, 5),
        ("death_star", 2025, 1, 3, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_in_flows == expected_table

    merged_in_flows_conversion_balance =
        TulipaIO.select_tbl(connection, "merged_in_flows_conversion_balance"; where_)
    expected_rows = [("death_star", 2025, 1, 1, 1), ("death_star", 2025, 1, 2, 5)]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_in_flows_conversion_balance == expected_table

    merged_out_flows = TulipaIO.select_tbl(connection, "merged_out_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 1, 4),
        ("death_star", 2025, 1, 4, 5),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_out_flows == expected_table

    merged_out_flows_conversion_balance =
        TulipaIO.select_tbl(connection, "merged_out_flows_conversion_balance"; where_)
    expected_rows = [("death_star", 2025, 1, 1, 3), ("death_star", 2025, 1, 4, 5)]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_out_flows_conversion_balance == expected_table

    merged_assets_and_out_flows =
        TulipaIO.select_tbl(connection, "merged_assets_and_out_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 1, 4),
        ("death_star", 2025, 1, 1, 5),
        ("death_star", 2025, 1, 4, 5),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_assets_and_out_flows == expected_table

    merged_all_flows = TulipaIO.select_tbl(connection, "merged_all_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 1, 2),
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 1, 4),
        ("death_star", 2025, 1, 2, 5),
        ("death_star", 2025, 1, 3, 5),
        ("death_star", 2025, 1, 4, 5),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_all_flows == expected_table

    merged_all = TulipaIO.select_tbl(connection, "merged_all"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 1, 2),
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 1, 4),
        ("death_star", 2025, 1, 1, 5),
        ("death_star", 2025, 1, 2, 5),
        ("death_star", 2025, 1, 3, 5),
        ("death_star", 2025, 1, 4, 5),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_all == expected_table

    merged_flows_conversion_balance =
        TulipaIO.select_tbl(connection, "merged_flows_conversion_balance"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 2, 5),
        ("death_star", 2025, 1, 4, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_flows_conversion_balance == expected_table

    merged_flows_relationship = TulipaIO.select_tbl(connection, "merged_flows_relationship"; where_)
    expected_rows = [
        ("death_star_output_1_death_star_output_2", 2025, 1, 1, 3),
        ("death_star_output_1_death_star_output_2", 2025, 1, 1, 4),
        ("death_star_output_1_death_star_output_2", 2025, 1, 4, 5),
        ("death_star_output_1_death_star_output_2", 2025, 1, 5, 5),
        ("death_star_output_1_input_1_death_star", 2025, 1, 1, 1),
        ("death_star_output_1_input_1_death_star", 2025, 1, 1, 3),
        ("death_star_output_1_input_1_death_star", 2025, 1, 2, 5),
        ("death_star_output_1_input_1_death_star", 2025, 1, 4, 5),
        ("input_1_death_star_death_star_output_1", 2025, 1, 1, 1),
        ("input_1_death_star_death_star_output_1", 2025, 1, 1, 3),
        ("input_1_death_star_death_star_output_1", 2025, 1, 2, 5),
        ("input_1_death_star_death_star_output_1", 2025, 1, 4, 5),
        ("input_1_death_star_input_2_death_star", 2025, 1, 1, 1),
        ("input_1_death_star_input_2_death_star", 2025, 1, 1, 2),
        ("input_1_death_star_input_2_death_star", 2025, 1, 2, 5),
        ("input_1_death_star_input_2_death_star", 2025, 1, 3, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_flows_relationship == expected_table

    merged_flows_and_connecting_assets = TulipaIO.select_tbl(
        connection,
        "merged_flows_and_connecting_assets";
        where_ = "asset LIKE '%death_star' ORDER BY asset, rep_period, time_block_start, time_block_end",
    )
    expected_rows = [
        ("input_1_death_star", 2025, 1, 1, 1),
        ("input_1_death_star", 2025, 1, 1, 3),
        ("input_1_death_star", 2025, 1, 1, 5),
        ("input_1_death_star", 2025, 1, 2, 5),
        ("input_1_death_star", 2025, 1, 4, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test merged_flows_and_connecting_assets == expected_table
end

@testitem "Test create_lowest_resolution_table!" setup = [CommonSetup, DataPreparationSetup] tags =
    [:unit, :data_preparation, :fast] begin
    # Need to create merged tables first since create_lowest_resolution_table! depends on them
    TulipaEnergyModel.create_merged_tables!(connection)
    TulipaEnergyModel.create_lowest_resolution_table!(connection)

    # Verify the results in the lowest resolution tables
    t_lowest_all = TulipaIO.select_tbl(connection, "t_lowest_all"; where_)
    expected_rows = [("death_star", 2025, 1, 1, 5)]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_lowest_all == expected_table

    t_lowest_all_flows = TulipaIO.select_tbl(connection, "t_lowest_all_flows"; where_)
    expected_rows = [("death_star", 2025, 1, 1, 4), ("death_star", 2025, 1, 5, 5)]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_lowest_all_flows == expected_table

    t_lowest_flows_conversion_balance =
        TulipaIO.select_tbl(connection, "t_lowest_flows_conversion_balance"; where_)
    expected_rows = [("death_star", 2025, 1, 1, 3), ("death_star", 2025, 1, 4, 5)]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_lowest_flows_conversion_balance == expected_table

    t_lowest_flows_relationship =
        TulipaIO.select_tbl(connection, "t_lowest_flows_relationship"; where_)
    expected_rows = [
        ("death_star_output_1_death_star_output_2", 2025, 1, 1, 4),
        ("death_star_output_1_death_star_output_2", 2025, 1, 5, 5),
        ("death_star_output_1_input_1_death_star", 2025, 1, 1, 3),
        ("death_star_output_1_input_1_death_star", 2025, 1, 4, 5),
        ("input_1_death_star_death_star_output_1", 2025, 1, 1, 3),
        ("input_1_death_star_death_star_output_1", 2025, 1, 4, 5),
        ("input_1_death_star_input_2_death_star", 2025, 1, 1, 2),
        ("input_1_death_star_input_2_death_star", 2025, 1, 3, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_lowest_flows_relationship == expected_table
end

@testitem "Test create_highest_resolution_table!" setup = [CommonSetup, DataPreparationSetup] tags =
    [:unit, :data_preparation, :fast] begin
    # Need to create merged tables first since create_highest_resolution_table! depends on them
    TulipaEnergyModel.create_merged_tables!(connection)
    TulipaEnergyModel.create_highest_resolution_table!(connection)

    # Verify the results in the highest resolution tables
    t_highest_all_flows = TulipaIO.select_tbl(connection, "t_highest_all_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 2, 2),
        ("death_star", 2025, 1, 3, 3),
        ("death_star", 2025, 1, 4, 4),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_highest_all_flows == expected_table

    t_highest_assets_and_out_flows =
        TulipaIO.select_tbl(connection, "t_highest_assets_and_out_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 4, 4),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_highest_assets_and_out_flows == expected_table

    t_highest_in_flows = TulipaIO.select_tbl(connection, "t_highest_in_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 1),
        ("death_star", 2025, 1, 2, 2),
        ("death_star", 2025, 1, 3, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_highest_in_flows == expected_table

    t_highest_out_flows = TulipaIO.select_tbl(connection, "t_highest_out_flows"; where_)
    expected_rows = [
        ("death_star", 2025, 1, 1, 3),
        ("death_star", 2025, 1, 4, 4),
        ("death_star", 2025, 1, 5, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_highest_out_flows == expected_table

    t_highest_flows_and_connecting_assets = TulipaIO.select_tbl(
        connection,
        "t_highest_flows_and_connecting_assets";
        where_ = "asset LIKE '%death_star' ORDER BY asset, rep_period, time_block_start, time_block_end",
    )
    expected_rows = [
        ("input_1_death_star", 2025, 1, 1, 1),
        ("input_1_death_star", 2025, 1, 2, 3),
        ("input_1_death_star", 2025, 1, 4, 5),
    ]
    expected_table = DataFrame(expected_rows, expected_cols)
    @test t_highest_flows_and_connecting_assets == expected_table
end

@testitem "Test total number of tables created" setup = [CommonSetup, DataPreparationSetup] tags =
    [:unit, :data_preparation, :fast] begin
    # Need to run all data preparation functions to get the full table count
    TulipaEnergyModel.create_merged_tables!(connection)
    TulipaEnergyModel.create_lowest_resolution_table!(connection)
    TulipaEnergyModel.create_highest_resolution_table!(connection)

    # test that the final number of tables is correct
    @test DataFrames.nrow(TulipaIO.show_tables(connection)) == 26
end

@testitem "Test _compute_durations" setup = [CommonSetup] tags = [:unit, :fast] begin
    row = (specification = "uniform", partition = "4")
    @test collect(TEM._compute_durations(row, 12)) == [4, 4, 4]
    @test collect(TEM._compute_durations(row, 24)) == [4, 4, 4, 4, 4, 4]
    @test_throws AssertionError TEM._compute_durations(row) # missing horizon_length

    row = (specification = "explicit", partition = "4;3")
    @test collect(TEM._compute_durations(row)) == [4, 3]
    row = (specification = "explicit", partition = "4;3;4;7")
    @test collect(TEM._compute_durations(row)) == [4, 3, 4, 7]

    row = (specification = "math", partition = "4x3+3x4")
    @test collect(TEM._compute_durations(row)) == [3, 3, 3, 3, 4, 4, 4]
    row = (specification = "math", partition = "1x12+2x3+1x4+2x1")
    @test collect(TEM._compute_durations(row)) == [12, 3, 3, 4, 1, 1]

    row = (specification = "bad",)
    @test_throws ErrorException TEM._compute_durations(row)
end
