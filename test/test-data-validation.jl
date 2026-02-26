@testitem "Test DataValidationException print" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    # Mostly to appease codecov
    error_msg = "DataValidationException: The following issues were found in the data:\n- example"
    @test_throws error_msg throw(TEM.DataValidationException(["example"]))
end

@testitem "Test having all tables and columns - missing table" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    for table in TulipaEnergyModel.tables_allowed_to_be_missing
        TEM._create_empty_unless_exists(connection, table)
    end

    DuckDB.query(connection, "DROP TABLE asset")
    @test TEM._validate_has_all_tables_and_columns!(connection) ==
          ["Table 'asset' expected but not found"]
end

@testitem "Test having all tables and columns - missing column" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    for table in TulipaEnergyModel.tables_allowed_to_be_missing
        TEM._create_empty_unless_exists(connection, table)
    end

    DuckDB.query(connection, "ALTER TABLE asset DROP COLUMN type")
    @test TEM._validate_has_all_tables_and_columns!(connection) ==
          ["Column 'type' is missing from table 'asset'"]
end

@testitem "Test duplicate rows - using fake data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    bad_data = DataFrame(
        :asset => ["ccgt", "demand", "wind", "ccgt", "demand"],
        :year => [2030, 2030, 2030, 2050, 2050],
        :value => [5.0, 10.0, 15.0, 7.0, 12.0],
    )
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, bad_data, "bad_data")
    @test TEM._validate_no_duplicate_rows!(connection, "bad_data", [:asset, :year]) == []
    @test TEM._validate_no_duplicate_rows!(connection, "bad_data", [:asset]) |> sort == [
        "Table bad_data has duplicate entries for (asset=ccgt)",
        "Table bad_data has duplicate entries for (asset=demand)",
    ]
end

@testitem "Test duplicate rows - duplicating rows of Tiny data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Duplicating rows in these specific tables
    for table in ("asset", "asset_both")
        DuckDB.query(connection, "INSERT INTO $table (FROM $table ORDER BY RANDOM() LIMIT 1)")
    end
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_no_duplicate_rows!(connection)
    @test length(error_messages) == 2
    # These tests assume an order in the validation of the tables
    @test occursin("Table asset has duplicate entries", error_messages[1])
    @test occursin("Table asset_both has duplicate entries", error_messages[2])
end

@testitem "Test schema oneOf constraints - bad asset type" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Change the table to force an error
    DuckDB.query(connection, "UPDATE asset SET type = 'badtype' WHERE asset = 'ccgt'")
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_schema_one_of_constraints!(connection)
    @test error_messages == ["Table 'asset' has bad value for column 'type': 'badtype'"]
end

@testitem "Test schema oneOf constraints - bad consumer balance sense" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Change the table to force an error
    DuckDB.query(
        connection,
        "UPDATE asset SET consumer_balance_sense = '<>' WHERE asset = 'demand'",
    )
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_schema_one_of_constraints!(connection)
    @test error_messages ==
          ["Table 'asset' has bad value for column 'consumer_balance_sense': '<>'"]
end

@testitem "Test schema oneOf constraints - bad unit commitment method" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Change the table to force an error
    DuckDB.query(
        connection,
        "UPDATE asset SET unit_commitment_method = 'bad' WHERE asset = 'demand'",
    )
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_schema_one_of_constraints!(connection)
    @test error_messages ==
          ["Table 'asset' has bad value for column 'unit_commitment_method': 'bad'"]
end

@testitem "Test schema oneOf constraints - bad specification" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Norse"))
    # Change the table to force an error
    DuckDB.query(
        connection,
        "UPDATE flows_rep_periods_partitions
        SET specification = 'bad'
        WHERE from_asset = 'Asgard_Solar'
            AND to_asset = 'Asgard_Battery'
            AND milestone_year = 2030
            AND rep_period = 1",
    )
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_schema_one_of_constraints!(connection)
    @test error_messages ==
          ["Table 'flows_rep_periods_partitions' has bad value for column 'specification': 'bad'"]
end

@testitem "Test only transport flows can be investable - using fake data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    # Create all four combinations of is_transport and investable
    flow = DataFrame(
        :from_asset => ["A1", "A2", "A3", "A4"],
        :to_asset => ["B", "B", "B", "B"],
        :is_transport => [false, false, true, true],
    )
    flow_milestone = DataFrame(
        :from_asset => ["A1", "A2", "A3", "A4"],
        :to_asset => ["B", "B", "B", "B"],
        :investable => [true, false, true, false],
    )
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, flow, "flow")
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")

    error_messages = TEM._validate_only_transport_flows_are_investable!(connection)
    @test error_messages == ["Flow ('A1', 'B') is investable but is not a transport flow"]
end

@testitem "Test only transport flows can be investable - using Tiny data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Create all four combinations of is_transport and investable
    # First set ccgt and ocgt to transport = TRUE
    DuckDB.query(
        connection,
        "UPDATE flow SET is_transport = TRUE WHERE from_asset in ('ccgt', 'ocgt')",
    )
    # Second set investable to wind and ocgt
    DuckDB.query(
        connection,
        "UPDATE flow_milestone SET investable = TRUE WHERE from_asset in ('wind','ocgt')",
    )
    @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
    error_messages = TEM._validate_only_transport_flows_are_investable!(connection)
    @test error_messages == ["Flow ('wind', 'demand') is investable but is not a transport flow"]
end

@testitem "Test flow_both does not contain non-transport flows - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    flow = DataFrame(
        :from_asset => ["A1", "A2"],
        :to_asset => ["B", "B"],
        :is_transport => [false, true],
    )
    flow_both = DataFrame(
        :from_asset => ["A1", "A2"],
        :to_asset => ["B", "B"],
        :milestone_year => [1, 2],
        :commission_year => [1, 2],
    )
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, flow, "flow")
    DuckDB.register_data_frame(connection, flow_both, "flow_both")

    error_messages = TEM._validate_flow_both_table_does_not_contain_non_transport_flows!(connection)
    @test error_messages == [
        "Unexpected (flow=('A1', 'B'), milestone_year=1, commission_year=1) in 'flow_both' because 'flow_both' should only contain transport flows.",
    ]
end

@testitem "Test flow_both does not contain non-transport flows - using Multi-year data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _multi_year_fixture()
    DuckDB.query(
        connection,
        """
        INSERT INTO flow_both (from_asset, to_asset, milestone_year, commission_year)
        VALUES ('wind', 'demand', 2030, 2030);
        """,
    )

    error_messages = TEM._validate_flow_both_table_does_not_contain_non_transport_flows!(connection)
    @test error_messages == [
        "Unexpected (flow=('wind', 'demand'), milestone_year=2030, commission_year=2030) in 'flow_both' because 'flow_both' should only contain transport flows.",
    ]
end

@testitem "Test foreign keys are valid - bad value for cat1" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    # Main table
    main_table = DataFrame(
        :asset => ["A1", "A2", "A3"],
        :cat1 => [missing, "good", "bad"],
        :cat2 => ["good", missing, "ugly"],
    )
    # Foreign table
    foreign_table = DataFrame(:category => ["good", "ugly"], :value => [1, 2])
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, main_table, "main_table")
    DuckDB.register_data_frame(connection, foreign_table, "foreign_table")

    error_messages = TEM._validate_foreign_key!(
        connection,
        "main_table",
        :cat1,
        "foreign_table",
        :category;
        allow_missing = true,
    )
    @test error_messages == [
        "Table 'main_table' column 'cat1' has invalid value 'bad'. Valid values should be among column 'category' of 'foreign_table'",
    ]
end

@testitem "Test foreign keys are valid - missing value for cat2" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    # Main table
    main_table = DataFrame(
        :asset => ["A1", "A2", "A3"],
        :cat1 => [missing, "good", "bad"],
        :cat2 => ["good", missing, "ugly"],
    )
    # Foreign table
    foreign_table = DataFrame(:category => ["good", "ugly"], :value => [1, 2])
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, main_table, "main_table")
    DuckDB.register_data_frame(connection, foreign_table, "foreign_table")

    error_messages = TEM._validate_foreign_key!(
        connection,
        "main_table",
        :cat2,
        "foreign_table",
        :category;
        allow_missing = true,
    )
    @test error_messages == String[]

    error_messages = TEM._validate_foreign_key!(
        connection,
        "main_table",
        :cat2,
        "foreign_table",
        :category;
        allow_missing = false,
    )
    @test error_messages == [
        "Table 'main_table' column 'cat2' has invalid value 'missing'. Valid values should be among column 'category' of 'foreign_table'",
    ]
end

@testitem "Test foreign keys are valid - using Tiny data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()

    # Doesn't throw
    TEM.create_internal_tables!(connection)

    DuckDB.query(connection, "UPDATE asset SET \"investment_group\" = 'bad' WHERE asset = 'ccgt'")
    @test_throws "Table 'asset' column 'investment_group' has invalid value 'bad'. Valid values should be among column 'name' of 'group_asset'" TEM.create_internal_tables!(
        connection,
    )
end

@testitem "Test groups have at least one member - using fake data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    asset = DataFrame(
        :asset => ["A1", "A2", "A3", "A4", "A5"],
        :investment_group => [missing, "good", "bad", "good", missing],
    )
    group_asset = DataFrame(:name => ["good", "bad", "ugly"], :value => [1, 2, 3])
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, asset, "asset")
    DuckDB.register_data_frame(connection, group_asset, "group_asset")

    error_messages = TEM._validate_group_consistency!(connection)
    @test error_messages ==
          ["Group 'ugly' in 'group_asset' has no members in 'asset', column 'investment_group'"]
end

@testitem "Test groups have at least one member - using Tiny data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()

    # Doesn't throw (and creates empty group_asset)
    TEM.create_internal_tables!(connection)

    # Modify group value to bad value
    DuckDB.query(connection, "INSERT INTO group_asset (name) VALUES ('lonely')")
    @test_throws "Group 'lonely' in 'group_asset' has no members in 'asset', column 'investment_group'" TEM.create_internal_tables!(
        connection,
    )
end

@testitem "Test simple investment method has only matching years - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    # For asset and flow
    # Validate have only matching years
    # Error otherwise and point out the unmatched rows
    connection = DBInterface.connect(DuckDB.DB)
    asset = DataFrame(:asset => ["A1", "A2"], :investment_method => ["simple", "none"])
    asset_both = DataFrame(
        :asset => ["A1", "A1", "A2", "A2"],
        :milestone_year => [1, 1, 1, 1],
        :commission_year => [1, 0, 1, 0],
    )
    flow = DataFrame(
        :from_asset => ["A1", "A2"],
        :to_asset => ["B", "B"],
        :is_transport => [false, true], # only flow A2-B will be tested
    )
    flow_both = DataFrame(
        :from_asset => ["A1", "A2", "A2"],
        :to_asset => ["B", "B", "B"],
        :milestone_year => [1, 1, 1],
        :commission_year => [1, 1, 0],
    )

    DuckDB.register_data_frame(connection, asset, "asset")
    DuckDB.register_data_frame(connection, asset_both, "asset_both")
    DuckDB.register_data_frame(connection, flow, "flow")
    DuckDB.register_data_frame(connection, flow_both, "flow_both")

    error_messages = TEM._validate_simple_method_has_only_matching_years!(String[], connection)
    @test error_messages == [
        "Unexpected (asset='A1', milestone_year=1, commission_year=0) in 'asset_both' for an asset='A1' with investment_method='simple'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Unexpected (asset='A2', milestone_year=1, commission_year=0) in 'asset_both' for an asset='A2' with investment_method='none'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Unexpected (from_asset='A2', to_asset='B', milestone_year=1, commission_year=0) in 'flow_both' for an flow=('A2', 'B') with default investment_method='simple/none'. For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
    ]
end

@testitem "Test simple investment method all milestone years covered - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    # For asset and flow
    # Validate that the data contains all milestone years where milestone year = commission year
    # Error otherwise and point out the missing milestone years
    connection = DBInterface.connect(DuckDB.DB)
    asset = DataFrame(:asset => ["A1", "A2"], :investment_method => ["simple", "none"])
    asset_milestone = DataFrame(:asset => ["A1", "A2"], :milestone_year => [1, 1])
    asset_both =
        DataFrame(:asset => ["A1", "A2"], :milestone_year => [1, 1], :commission_year => [0, 0])
    flow = DataFrame(
        :from_asset => ["A1", "A2"],
        :to_asset => ["B", "B"],
        :is_transport => [false, true], # only flow A2-B will be tested
    )
    flow_milestone =
        DataFrame(:from_asset => ["A1", "A2"], :to_asset => ["B", "B"], :milestone_year => [1, 1])
    flow_both = DataFrame(
        :from_asset => ["A1", "A2"],
        :to_asset => ["B", "B"],
        :milestone_year => [1, 1],
        :commission_year => [0, 0],
    )
    DuckDB.register_data_frame(connection, asset, "asset")
    DuckDB.register_data_frame(connection, asset_milestone, "asset_milestone")
    DuckDB.register_data_frame(connection, asset_both, "asset_both")
    DuckDB.register_data_frame(connection, flow, "flow")
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")
    DuckDB.register_data_frame(connection, flow_both, "flow_both")

    error_messages =
        TEM._validate_simple_method_all_milestone_years_are_covered!(String[], connection)

    @test error_messages == [
        "Missing information in 'asset_both': Asset 'A1' has investment_method='simple' but there is no row (asset='A1', milestone_year=1, commission_year=1). For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Missing information in 'asset_both': Asset 'A2' has investment_method='none' but there is no row (asset='A2', milestone_year=1, commission_year=1). For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Missing information in 'flow_both': Flow ('A2', 'B') currently only has investment_method='simple/none' but there is no row (from_asset='A2', to_asset='B', milestone_year=1, commission_year=1). For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
    ]
end

@testitem "Test simple investment method has only matching years - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    # For asset and flow
    # Validate have only matching years
    # Error otherwise and point out the unmatched rows
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        INSERT INTO asset_both (asset, milestone_year, commission_year)
        VALUES ('ccgt', 2030, 2029);
        UPDATE flow SET is_transport = TRUE WHERE from_asset = 'wind' AND to_asset = 'demand';
        INSERT INTO flow_both (from_asset, to_asset, milestone_year, commission_year)
        VALUES ('wind', 'demand', 2030, 2029);
        """,
    )
    error_messages = TEM._validate_simple_method_has_only_matching_years!(String[], connection)
    @test error_messages == [
        "Unexpected (asset='ccgt', milestone_year=2030, commission_year=2029) in 'asset_both' for an asset='ccgt' with investment_method='simple'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Unexpected (from_asset='wind', to_asset='demand', milestone_year=2030, commission_year=2029) in 'flow_both' for an flow=('wind', 'demand') with default investment_method='simple/none'. For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
    ]
end

@testitem "Test simple investment method all milestone years covered - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    # For asset and flow
    # Validate that the data contains all milestone years where milestone year = commission year
    # Error otherwise and point out the missing milestone years
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        UPDATE asset_both SET commission_year = 2029 WHERE asset = 'ccgt' AND milestone_year = 2030;
        UPDATE flow SET is_transport = TRUE WHERE from_asset = 'wind' AND to_asset = 'demand';
        UPDATE flow_both SET commission_year = 2029 WHERE from_asset = 'wind' AND to_asset = 'demand' AND milestone_year = 2030;
        """,
    )
    error_messages =
        TEM._validate_simple_method_all_milestone_years_are_covered!(String[], connection)
    @test error_messages == [
        "Missing information in 'asset_both': Asset 'ccgt' has investment_method='simple' but there is no row (asset='ccgt', milestone_year=2030, commission_year=2030). For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        "Missing information in 'flow_both': Flow ('wind', 'demand') currently only has investment_method='simple/none' but there is no row (from_asset='wind', to_asset='demand', milestone_year=2030, commission_year=2030). For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
    ]
end

@testitem "Test binary storage method has investment limit - using fake data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    asset = DataFrame(
        :asset => ["storage_1", "storage_2", "storage_3", "storage_4", "storage_5"],
        :type => repeat(["storage"], 5),
        :use_binary_storage_method => ["binary", "binary", "binary", missing, "binary"],
    )
    asset_milestone = DataFrame(
        :asset => ["storage_1", "storage_2", "storage_3", "storage_4", "storage_5"],
        :milestone_year => repeat([1], 5),
        :investable => [true, true, true, true, false],
    )
    asset_commission = DataFrame(
        :asset => ["storage_1", "storage_2", "storage_3", "storage_4", "storage_5"],
        :milestone_year => repeat([1], 5),
        :commission_year => repeat([1], 5),
        :investment_limit => [missing, 0, 1, missing, missing],
    )
    DuckDB.register_data_frame(connection, asset, "asset")
    DuckDB.register_data_frame(connection, asset_milestone, "asset_milestone")
    DuckDB.register_data_frame(connection, asset_commission, "asset_commission")
    error_messages = TEM._validate_use_binary_storage_method_has_investment_limit!(connection)
    @test error_messages == [
        "Incorrect investment_limit = missing for investable storage asset 'storage_1' with use_binary_storage_method = 'binary' for milestone_year 1. The investment_limit at commission_year 1 should be greater than 0 in 'asset_commission'.",
        "Incorrect investment_limit = 0 for investable storage asset 'storage_2' with use_binary_storage_method = 'binary' for milestone_year 1. The investment_limit at commission_year 1 should be greater than 0 in 'asset_commission'.",
    ]
end

@testitem "Test binary storage method has investment limit - using Storage data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _storage_fixture()
    DuckDB.query(
        connection,
        """
        UPDATE asset SET use_binary_storage_method = 'binary' WHERE asset = 'battery';
        UPDATE asset_milestone SET investable = TRUE WHERE asset in ('battery', 'phs');
        """,
    )
    error_messages = TEM._validate_use_binary_storage_method_has_investment_limit!(connection)
    @test error_messages == [
        "Incorrect investment_limit = missing for investable storage asset 'battery' with use_binary_storage_method = 'binary' for milestone_year 2030. The investment_limit at commission_year 2030 should be greater than 0 in 'asset_commission'.",
    ]
end
@testitem "Test DC OPF data - reactance > 0 using fake data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    flow_milestone = DataFrame(
        :from_asset => ["A", "A", "A"],
        :to_asset => ["B", "B", "B"],
        :milestone_year => [1, 2, 3],
        :reactance => [1.0, 0.0, -1.0],
    )
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")
    error_messages = TEM._validate_reactance_must_be_greater_than_zero!(String[], connection)
    @test error_messages == [
        "Incorrect reactance = 0.0 for flow ('A', 'B') for milestone_year 2 in 'flow_milestone'. The reactance should be greater than 0.",
        "Incorrect reactance = -1.0 for flow ('A', 'B') for milestone_year 3 in 'flow_milestone'. The reactance should be greater than 0.",
    ]
end

@testitem "Test DC OPF data - only apply to non-investable transport flows using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    flow_milestone = DataFrame(
        :from_asset => ["A", "A", "B"],
        :to_asset => ["B", "B", "C"],
        :milestone_year => [1, 2, 1],
        :investable => [false, true, false],
        :dc_opf => [true, true, true],
    )
    DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")
    flow = DataFrame(
        :from_asset => ["A", "B"],
        :to_asset => ["B", "C"],
        :is_transport => [true, false],
    )
    DuckDB.register_data_frame(connection, flow, "flow")
    error_messages =
        TEM._validate_dc_opf_only_apply_to_non_investable_transport_flows!(String[], connection)
    @test error_messages == [
        "Incorrect use of dc-opf method for flow ('A', 'B') for milestone_year 2 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
        "Incorrect use of dc-opf method for flow ('B', 'C') for milestone_year 1 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
    ]
end

@testitem "Test DC OPF data - reactance > 0 using Tiny data" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        UPDATE flow_milestone SET reactance = 0.0 WHERE from_asset = 'wind' and to_asset = 'demand';
        UPDATE flow_milestone SET reactance = -1.0 WHERE from_asset = 'solar' and to_asset = 'demand';
        """,
    )
    error_messages = TEM._validate_reactance_must_be_greater_than_zero!(String[], connection)
    @test error_messages == [
        "Incorrect reactance = 0.0 for flow ('wind', 'demand') for milestone_year 2030 in 'flow_milestone'. The reactance should be greater than 0.",
        "Incorrect reactance = -1.0 for flow ('solar', 'demand') for milestone_year 2030 in 'flow_milestone'. The reactance should be greater than 0.",
    ]
end

@testitem "Test DC OPF data - only apply to non-investable transport flows using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        UPDATE flow SET is_transport = true WHERE from_asset = 'wind' and to_asset = 'demand';
        UPDATE flow_milestone SET dc_opf = true, investable = true WHERE from_asset = 'wind' and to_asset = 'demand';
        UPDATE flow_milestone SET dc_opf = true, investable = false WHERE from_asset = 'solar' and to_asset = 'demand';
        """,
    )
    error_messages =
        TEM._validate_dc_opf_only_apply_to_non_investable_transport_flows!(String[], connection)
    @test error_messages == [
        "Incorrect use of dc-opf method for flow ('wind', 'demand') for milestone_year 2030 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
        "Incorrect use of dc-opf method for flow ('solar', 'demand') for milestone_year 2030 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
    ]
end

@testitem "Test investment method and asset types consistency - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    asset = DataFrame(
        :asset => ["A1", "A2", "A3", "A4", "A5", "A6", "A7"],
        :type => [
            "producer",
            "conversion",
            "storage",
            "consumer",
            "consumer",
            "consumer",
            "consumer",
        ],
        :investment_method => ["simple", "none", "none", "simple", "compact", "none", "none"],
    )
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, asset, "asset")

    error_messages =
        TEM._validate_certain_asset_types_can_only_have_none_investment_methods!(connection)
    @test error_messages == [
        "Incorrect use of investment method 'simple' for asset 'A4' of type 'consumer'. Consumer assets can only have 'none' investment method.",
        "Incorrect use of investment method 'compact' for asset 'A5' of type 'consumer'. Consumer assets can only have 'none' investment method.",
    ]
end

@testitem "Test investment method and asset types consistency - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(connection, "UPDATE asset SET investment_method = 'simple' WHERE asset = 'demand'")
    error_messages =
        TEM._validate_certain_asset_types_can_only_have_none_investment_methods!(connection)
    @test error_messages == [
        "Incorrect use of investment method 'simple' for asset 'demand' of type 'consumer'. Consumer assets can only have 'none' investment method.",
    ]
end

@testitem "Check consistency between asset_commission and asset_both - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    asset_both =
        DataFrame(:asset => ["A", "A"], :milestone_year => [1, 2], :commission_year => [0, 0])
    DuckDB.register_data_frame(connection, asset_both, "asset_both")

    asset_commission = DataFrame(:asset => ["A", "A"], :commission_year => [-1, 1])
    DuckDB.register_data_frame(connection, asset_commission, "asset_commission")

    error_messages = TEM._validate_asset_commission_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Missing commission_year = 0 for asset 'A' in 'asset_commission' given (asset 'A', milestone_year = 1, commission_year = 0) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        "Missing commission_year = 0 for asset 'A' in 'asset_commission' given (asset 'A', milestone_year = 2, commission_year = 0) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        "Unexpected commission_year = -1 for asset 'A' in 'asset_commission'. The commission_year should match the one in 'asset_both'.",
        "Unexpected commission_year = 1 for asset 'A' in 'asset_commission'. The commission_year should match the one in 'asset_both'.",
    ]
end
@testitem "Check consistency between asset_commission and asset_both - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(connection, "UPDATE asset_commission SET commission_year = 0 WHERE asset = 'wind'")
    error_messages = TEM._validate_asset_commission_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Missing commission_year = 2030 for asset 'wind' in 'asset_commission' given (asset 'wind', milestone_year = 2030, commission_year = 2030) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        "Unexpected commission_year = 0 for asset 'wind' in 'asset_commission'. The commission_year should match the one in 'asset_both'.",
    ]
end

@testitem "Check consistency between flow_commission and asset_both - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    asset_both = DataFrame(
        :asset => ["A", "A", "B"],
        :milestone_year => [1, 1, 1],
        :commission_year => [0, 1, 1],
    )
    DuckDB.register_data_frame(connection, asset_both, "asset_both")

    flow_commission = DataFrame(
        :from_asset => ["A", "B", "B"],
        :to_asset => ["B", "A", "A"],
        :commission_year => [1, -1, 1],
    )
    DuckDB.register_data_frame(connection, flow_commission, "flow_commission")

    asset = DataFrame(:asset => ["A", "B"], :investment_method => ["semi-compact", "semi-compact"])
    DuckDB.register_data_frame(connection, asset, "asset")

    error_messages = TEM._validate_flow_commission_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Missing commission_year = 0 for the outgoing flow of asset 'A' in 'flow_commission' given (asset 'A', milestone_year = 1, commission_year = 0) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        "Unexpected commission_year = -1 for the outgoing flow of asset 'B' in 'flow_commission'. The commission_year should match the one in 'asset_both'.",
    ]
end

@testitem "Check consistency between flow_commission and asset_both - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    DuckDB.query(
        connection,
        """
        UPDATE flow_commission SET commission_year = 0 WHERE from_asset = 'wind';
        UPDATE asset SET investment_method = 'semi-compact' WHERE asset = 'wind';
        """,
    )
    error_messages = TEM._validate_flow_commission_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Missing commission_year = 2030 for the outgoing flow of asset 'wind' in 'flow_commission' given (asset 'wind', milestone_year = 2030, commission_year = 2030) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        "Unexpected commission_year = 0 for the outgoing flow of asset 'wind' in 'flow_commission'. The commission_year should match the one in 'asset_both'.",
    ]
end

@testitem "Check that stochastic scenario probabilities sum to 1 - no error" setup = [CommonSetup] tags =
    [:unit, :data_validation, :fast] begin
    stochastic_scenario = DataFrame(:scenario => [1, 2, 3], :probability => [0.3, 0.4, 0.3])
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, stochastic_scenario, "stochastic_scenario")

    error_messages = TEM._validate_stochastic_scenario_probabilities_sum_to_one!(connection)
    @test error_messages == []
end

@testitem "Check that stochastic scenario probabilities sum to 1 - throw error" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    stochastic_scenario = DataFrame(:scenario => [1, 2], :probability => [0.499, 0.5])
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(connection, stochastic_scenario, "stochastic_scenario")

    error_messages = TEM._validate_stochastic_scenario_probabilities_sum_to_one!(
        connection;
        tolerance = 1e-5, # testing passing a tolerance different from default
    )
    @test error_messages == [
        "Sum of probabilities in 'stochastic_scenario' table is 0.999, but should be approximately 1.0 (tolerance: 1.0e-5)",
    ]
end

@testitem "Check that stochastic scenario probabilities sum to 1 - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()

    # Doesn't throw (creates default stochastic_scenario table with probabilities summing to 1)
    TEM.create_internal_tables!(connection)

    # Modify stochastic_scenario to have bad probabilities
    DuckDB.query(
        connection,
        """
        UPDATE stochastic_scenario SET probability = 0.8 WHERE scenario = 1;
        """,
    )
    @test_throws "Sum of probabilities in 'stochastic_scenario' table is 0.8, but should be approximately 1.0 (tolerance: 0.001)" TEM.create_internal_tables!(
        connection,
    )
end

@testitem "Check that consumer unit commitment implies other bid-related data to be correct" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    using TulipaBuilder
    using TulipaClustering

    year = 2030
    year_length = 12

    function create_problem_base()
        tulipa = TulipaData{String}()
        add_asset!(tulipa, "Generator", :producer; capacity = 50.0, initial_units = 1.0)
        add_asset!(tulipa, "Bid Manager", :consumer; peak_demand = 0.0) # no demand
        add_flow!(tulipa, "Generator", "Bid Manager"; operational_cost = 5.0)
        # Because we at least one profile
        attach_profile!(tulipa, "Bid Manager", :demand, 2030, zeros(year_length))

        return tulipa
    end

    function create_connection_and_prepare(tulipa)
        connection = create_connection(tulipa)
        TulipaClustering.dummy_cluster!(
            connection;
            layout = TulipaClustering.ProfilesTableLayout(; year = :milestone_year),
        )
        TulipaEnergyModel.populate_with_defaults!(connection)
        return connection
    end

    """
        add_new_bid!(tulipa_data, bid_name; price, quantity, ...)

    Creates a new bid using TulipaBuilder for the problem created by `create_problem_base`.
    The `price` and `quantity` are expected keywords. The extra keywords are used to give
    incorrect values to the problem. Using these extra keywords, we can create
    a bid, except for one wrong thing.
    """
    function add_new_bid!(
        tulipa,
        bid_name;
        price,
        quantity,
        add_demand_profile = true,
        add_flow_from_bid_manager = true,
        add_loop = true,
        capacity = 1.0,
        consumer_balance_sense = "==",
        flow_from_bid_manager = true,
        initial_units = 1.0,
        set_partition = true,
        type = :consumer,
        unit_commitment = true,
        unit_commitment_integer = true,
        unit_commitment_method = "basic",
    )
        profile = zeros(year_length)
        for (t, qty) in quantity
            profile[t] = qty
        end
        add_asset!(
            tulipa,
            bid_name,
            type;
            capacity,
            consumer_balance_sense,
            initial_units,
            min_operating_point = 1.0,
            peak_demand = maximum(profile),
            unit_commitment,
            unit_commitment_integer,
            unit_commitment_method,
        )
        if set_partition
            set_partition!(tulipa, bid_name, year, 1, year_length)
        end
        if add_loop
            add_flow!(tulipa, bid_name, bid_name)
        end
        if add_flow_from_bid_manager
            add_flow!(tulipa, "Bid Manager", bid_name; operational_cost = -price)
        end
        if add_demand_profile
            attach_profile!(tulipa, bid_name, :demand, year, profile)
        end

        return tulipa
    end

    @testset "All data is correct" begin
        tulipa = create_problem_base()
        add_new_bid!(tulipa, "bid1"; price = 1.0, quantity = Dict(3 => 30.0, 4 => 50.0))
        connection = create_connection_and_prepare(tulipa)

        error_messages = TEM._validate_bid_related_data!(connection)
        @test length(error_messages) == 0
    end

    """
        error_messages_for_wrong_problem(; kwargs...)

    Helper function to create a new problem with a bid. The `kwargs` are
    expected wrong values. Returns the error messages generated by
    `_validate_bid_related_data`.
    """
    function error_messages_for_wrong_problem(; num_years = 1, num_rep_periods = 1, kwargs...)
        tulipa = create_problem_base()
        add_new_bid!(tulipa, "bid1"; price = 1.0, quantity = Dict(3 => 30.0, 4 => 50.0), kwargs...)
        connection = create_connection_and_prepare(tulipa)
        if num_years > 1
            for i in 2:num_years
                DuckDB.query(
                    connection,
                    """
                    INSERT INTO year_data (year, length, is_milestone)
                    VALUES ($(2020 + 10i), 24, false)
                    """,
                )
            end
        end
        if num_rep_periods > 1
            for i in 2:num_rep_periods
                DuckDB.query(
                    connection,
                    """
                    INSERT INTO rep_periods_data (milestone_year, rep_period, num_timesteps, resolution)
                    VALUES (2030, $i, 24, 1.0)
                    """,
                )
            end
        end

        error_messages = TEM._validate_bid_related_data!(connection)
        return error_messages
    end

    @testset "When $bad_key_value_pair" for (
        bad_key_value_pair, # Which change introduces an error?
        expected_num_errors, # How many checks fail because of it (see sufficient cases for bids, in src/data_validation.jl)
        expected_error_message,
    ) in (
        # These should fail for all 3 sufficient cases
        (
            :add_demand_profile => false,
            3,
            "a profile in assets_profiles with profile_type = 'demand', but found none",
        ),
        (:capacity => 0.5, 3, "asset.capacity = 1.0, but found 0.5"),
        (
            :consumer_balance_sense => "<=",
            3,
            "asset.consumer_balance_sense = \"==\", but found \"<=\"",
        ),
        (:initial_units => 0.0, 3, "asset_both.initial_units = 1.0, but found 0.0"),
        (
            :set_partition => false,
            3,
            "wrong asset partition. It should be uniform and equal to num_timesteps for all representative periods",
        ),
        (:num_rep_periods => 3, 3, "only 1 representative period, but found 3"),
        (:num_years => 3, 3, "only 1 year, but found 3"),
        (:unit_commitment_integer => false, 3, "asset.unit_commitment_integer = true"),
        (:unit_commitment_method => "", 3, "asset.unit_commitment_method = \"basic\""),
        # These are excluding cases, i.e., one of the sufficient cases won't be generated, so only 2 will error.
        (
            :add_flow_from_bid_manager => false,
            2,
            "an incoming flow with negative operational_cost, but found none",
        ),
        (:add_loop => false, 2, "a loop flow, but found none"),
        (:price => -1.0, 2, "an incoming flow with negative operational_cost, but found none"),
        (:type => :producer, 2, "asset.type = 'consumer' and asset.unit_commitment = true"),
        (:unit_commitment => false, 2, "asset.type = 'consumer' and asset.unit_commitment = true"),
    )
        error_messages = error_messages_for_wrong_problem(; Dict(bad_key_value_pair)...)
        @test length(error_messages) == expected_num_errors
        @test all(contains(msg, expected_error_message) for msg in error_messages)
    end
end

@testitem "Check that commodity_price profile requires flow_milestone.commodity_price > 0" tags =
    [:fast, :validation] setup = [CommonSetup] begin
    connection = _tiny_fixture()

    # Add a commodity_price profile and link to (demand, flow)
    DuckDB.query(
        connection,
        """
        INSERT INTO profiles_rep_periods BY NAME
        SELECT
            'commodity_price-wind-demand' AS profile_name,
            * EXCLUDE (profile_name)
        FROM profiles_rep_periods
        WHERE profile_name = 'availability-wind'
        """,
    )
    DuckDB.query(
        connection,
        """
        INSERT INTO flows_profiles (from_asset, to_asset, milestone_year, profile_type, profile_name)
        VALUES ('wind', 'demand', 2030, 'commodity_price', 'commodity_price-wind-demand')
        """,
    )
    @test_throws "Flow (wind, demand) is associated with a 'commodity_price' profile, so it should have flow_milestone.commodity_price > 0, but we found 0.0" TEM.create_internal_tables!(
        connection,
    )

    # If commodity_price is > 0, no more error
    DuckDB.query(
        connection,
        """
        UPDATE flow_milestone
        SET commodity_price = 3.14
        WHERE from_asset = 'wind' AND to_asset = 'demand'
        """,
    )
    @test TEM._validate_commodity_price_consistency!(connection) == String[]

    # If the flows_profiles table does not exist, no more error (this is mostly here to incrase coverage)
    connection = _tiny_fixture()
    DuckDB.query(connection, "DROP TABLE flows_profiles")
    @test TEM._validate_commodity_price_consistency!(connection) == String[]
end

@testitem "Check consistency between investable and asset_both - using fake data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    asset_milestone = DataFrame(
        :asset => ["A", "B", "C"],
        :milestone_year => [1, 1, 1],
        :investable => [true, true, false],
    )
    # A is missing and should generated an error message.
    # C is missing as well, but is not investable, so it is fine.
    asset_both = DataFrame(:asset => ["B"], :milestone_year => [1], :commission_year => [1])
    DuckDB.register_data_frame(connection, asset_milestone, "asset_milestone")
    DuckDB.register_data_frame(connection, asset_both, "asset_both")

    error_messages = TEM._validate_investable_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Investable asset 'A' with milestone_year=1 in 'asset_milestone' does not have a corresponding entry (asset='A', milestone_year=1, commission_year=1) in 'asset_both'.",
    ]
end

@testitem "Check consistency between investable and asset_both - using Tiny data" setup =
    [CommonSetup] tags = [:unit, :data_validation, :fast] begin
    connection = _tiny_fixture()
    # Remove the asset_both entry for 'wind' at milestone_year=2030 with commission_year=2030
    # so that the investable 'wind' asset has no matching entry
    DuckDB.query(
        connection,
        "DELETE FROM asset_both WHERE asset = 'wind' AND milestone_year = 2030 AND commission_year = 2030",
    )
    error_messages = TEM._validate_investable_and_asset_both_consistency!(connection)
    @test error_messages == [
        "Investable asset 'wind' with milestone_year=2030 in 'asset_milestone' does not have a corresponding entry (asset='wind', milestone_year=2030, commission_year=2030) in 'asset_both'.",
    ]
end
