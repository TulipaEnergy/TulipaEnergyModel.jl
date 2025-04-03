const TEM = TulipaEnergyModel

@testset "Test DataValidationException print" begin
    # Mostly to appease codecov
    error_msg = "DataValidationException: The following issues were found in the data:\n- example"
    @test_throws error_msg throw(TEM.DataValidationException(["example"]))
end

@testset "Test having all tables and columns" begin
    @testset "Starting from Tiny and deleting" begin
        connection = _tiny_fixture()
        for table in TulipaEnergyModel.tables_allowed_to_be_missing
            TEM._create_empty_unless_exists(connection, table)
        end

        DuckDB.query(connection, "DROP TABLE asset")
        @test TEM._validate_has_all_tables_and_columns!(connection) ==
              ["Table 'asset' expected but not found"]
    end

    @testset "Starting from Tiny and deleting" begin
        connection = _tiny_fixture()
        for table in TulipaEnergyModel.tables_allowed_to_be_missing
            TEM._create_empty_unless_exists(connection, table)
        end

        DuckDB.query(connection, "ALTER TABLE asset DROP COLUMN type")
        @test TEM._validate_has_all_tables_and_columns!(connection) ==
              ["Column 'type' is missing from table 'asset'"]
    end
end

@testset "Test duplicate rows" begin
    @testset "Using fake data" begin
        bad_data = DataFrame(
            :asset => ["ccgt", "demand", "wind", "ccgt", "demand"],
            :year => [2030, 2030, 2030, 2050, 2050],
            :value => [5.0, 10.0, 15.0, 7.0, 12.0],
        )
        connection = DBInterface.connect(DuckDB.DB)
        DuckDB.register_data_frame(connection, bad_data, "bad_data")
        @test TEM._validate_no_duplicate_rows!(connection, "bad_data", [:asset, :year]) == []
        @test TEM._validate_no_duplicate_rows!(connection, "bad_data", [:asset]) == [
            "Table bad_data has duplicate entries for (asset=ccgt)",
            "Table bad_data has duplicate entries for (asset=demand)",
        ]
    end

    @testset "Duplicating rows of Tiny data" begin
        connection = _tiny_fixture()
        # Duplicating rows in these specific tables
        for table in ("asset", "asset_both", "flow_both")
            DuckDB.query(connection, "INSERT INTO $table (FROM $table ORDER BY RANDOM() LIMIT 1)")
        end
        @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
        error_messages = TEM._validate_no_duplicate_rows!(connection)
        @test length(error_messages) == 3
        # These tests assume an order in the validation of the tables
        @test occursin("Table asset has duplicate entries", error_messages[1])
        @test occursin("Table asset_both has duplicate entries", error_messages[2])
        @test occursin("Table flow_both has duplicate entries", error_messages[3])
    end
end

@testset "Check Schema oneOf constraints" begin
    @testset "Changing Tiny data asset table (bad type)" begin
        connection = _tiny_fixture()
        # Change the table to force an error
        DuckDB.query(connection, "UPDATE asset SET type = 'badtype' WHERE asset = 'ccgt'")
        @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
        error_messages = TEM._validate_schema_one_of_constraints!(connection)
        @test error_messages == ["Table 'asset' has bad value for column 'type': 'badtype'"]
    end

    @testset "Changing Tiny data asset table (bad consumer_balance_sense)" begin
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

    @testset "Changing Norse data flows_rep_periods_partitions table (bad specification)" begin
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Norse"))
        # Change the table to force an error
        DuckDB.query(
            connection,
            "UPDATE flows_rep_periods_partitions
            SET specification = 'bad'
            WHERE from_asset = 'Asgard_Solar'
                AND to_asset = 'Asgard_Battery'
                AND year = 2030
                AND rep_period = 1",
        )
        @test_throws TEM.DataValidationException TEM.create_internal_tables!(connection)
        error_messages = TEM._validate_schema_one_of_constraints!(connection)
        @test error_messages == [
            "Table 'flows_rep_periods_partitions' has bad value for column 'specification': 'bad'",
        ]
    end
end

@testset "Check only transport flows can be investable" begin
    @testset "Using fake data" begin
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

    @testset "Using Tiny data" begin
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
        @test error_messages ==
              ["Flow ('wind', 'demand') is investable but is not a transport flow"]
    end
end

@testset "Check that foreign keys are valid" begin
    @testset "Using fake data" begin
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

        @testset "'bad' value for cat1" begin
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

        @testset "missing value for cat2" begin
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
    end

    @testset "Using Tiny data" begin
        connection = _tiny_fixture()

        # Doesn't throw
        TEM.create_internal_tables!(connection)

        DuckDB.query(connection, "UPDATE asset SET \"group\" = 'bad' WHERE asset = 'ccgt'")
        @test_throws "Table 'asset' column 'group' has invalid value 'bad'. Valid values should be among column 'name' of 'group_asset'" TEM.create_internal_tables!(
            connection,
        )
    end
end

@testset "Check that groups have at least one member" begin
    @testset "Using fake data" begin
        asset = DataFrame(
            :asset => ["A1", "A2", "A3", "A4", "A5"],
            :group => [missing, "good", "bad", "good", missing],
        )
        group_asset = DataFrame(:name => ["good", "bad", "ugly"], :value => [1, 2, 3])
        connection = DBInterface.connect(DuckDB.DB)
        DuckDB.register_data_frame(connection, asset, "asset")
        DuckDB.register_data_frame(connection, group_asset, "group_asset")

        error_messages = TEM._validate_group_consistency!(connection)
        @test error_messages ==
              ["Group 'ugly' in 'group_asset' has no members in 'asset', column 'group'"]
    end

    @testset "Using Tiny data" begin
        connection = _tiny_fixture()

        # Doesn't throw (and creates empty group_asset)
        TEM.create_internal_tables!(connection)

        # Modify group value to bad value
        DuckDB.query(connection, "INSERT INTO group_asset (name) VALUES ('lonely')")
        @test_throws "Group 'lonely' in 'group_asset' has no members in 'asset', column 'group'" TEM.create_internal_tables!(
            connection,
        )
    end
end

@testset "Check data consistency for simple investment method" begin
    @testset "Using fake data" begin
        @testset "Where there is only one row of data for milestone year not equal to commission year " begin
            connection = DBInterface.connect(DuckDB.DB)
            # Test 1:
            # For asset and flow
            # Having exactly one row of data per milestone year where milestone year does not equal to commission year
            asset = DataFrame(:asset => ["A1", "A2"], :investment_method => ["simple", "none"])
            asset_both = DataFrame(
                :asset => ["A1", "A2"],
                :milestone_year => [1, 1],
                :commission_year => [0, 0],
            )
            flow = DataFrame(
                :from_asset => ["A1", "A2"],
                :to_asset => ["B", "B"],
                :is_transport => [false, true], # only flow A2-B will be tested
            )
            flow_both = DataFrame(
                :from_asset => ["A1", "A2"],
                :to_asset => ["B", "B"],
                :milestone_year => [1, 1],
                :commission_year => [0, 0],
            )

            DuckDB.register_data_frame(connection, asset, "asset")
            DuckDB.register_data_frame(connection, asset_both, "asset_both")
            DuckDB.register_data_frame(connection, flow, "flow")
            DuckDB.register_data_frame(connection, flow_both, "flow_both")

            error_messages =
                TEM._validate_simple_method_data_contains_only_one_row_where_milestone_year_not_equal_to_commission_year!(
                    String[],
                    connection,
                )
            @test error_messages == [
                "'A1' uses 'simple' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there is exactly one row of data where milestone year 1 does not equal commission year in 'asset_both'.",
                "'A2' uses 'none' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there is exactly one row of data where milestone year 1 does not equal commission year in 'asset_both'.",
                "By default, transport flow ('A2', 'B') uses simple/none investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there is exactly one row of data where milestone year 1 does not equal commission year in 'flow_both'.",
            ]
        end

        @testset "Where there are more than one row of data" begin
            connection = DBInterface.connect(DuckDB.DB)
            # For asset and flow
            # Having more than one row of data per milestone year
            asset_both = DataFrame(
                :asset => ["A1", "A1", "A2", "A2"],
                :milestone_year => [1, 1, 1, 1],
                :commission_year => [1, 0, 1, 0],
            )
            flow_both = DataFrame(
                :from_asset => ["A1", "A2", "A2"],
                :to_asset => ["B", "B", "B"],
                :milestone_year => [1, 1, 1],
                :commission_year => [1, 1, 0],
            )
            DuckDB.query(connection, "DROP VIEW IF EXISTS asset_both;")
            DuckDB.query(connection, "DROP VIEW IF EXISTS flow_both;")
            DuckDB.register_data_frame(connection, asset_both, "asset_both")
            DuckDB.register_data_frame(connection, flow_both, "flow_both")

            error_messages =
                TEM._validate_simple_method_data_contains_more_than_one_row!(String[], connection)

            @test error_messages == [
                "'A1' uses 'simple' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there are 2 rows of data for milestone year 1 in 'asset_both'.",
                "'A2' uses 'none' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there are 2 rows of data for milestone year 1 in 'asset_both'.",
                "By default, transport flow ('A2', 'B') uses simple/none investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there are 2 rows of data for milestone year 1 in 'flow_both'.",
            ]
        end
    end

    @testset "Using Tiny data" begin
        connection = _tiny_fixture()
        @testset "Where there is only one row of data for milestone year not equal to commission year " begin
            # Test 1:
            # For asset and flow
            # Having exactly one row of data where milestone year does not equal to commission year
            DuckDB.query(
                connection,
                """
                UPDATE asset_both SET commission_year = 2029 WHERE asset = 'ccgt' AND milestone_year = 2030;
                UPDATE flow SET is_transport = TRUE WHERE from_asset = 'wind' AND to_asset = 'demand';
                UPDATE flow_both SET commission_year = 2029 WHERE from_asset = 'wind' AND to_asset = 'demand' AND milestone_year = 2030;
                """,
            )
            error_messages = TEM._validate_simple_method_data_consistency!(connection)
            @test error_messages == [
                "'ccgt' uses 'none' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there is exactly one row of data where milestone year 2030 does not equal commission year in 'asset_both'.",
                "By default, transport flow ('wind', 'demand') uses simple/none investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there is exactly one row of data where milestone year 2030 does not equal commission year in 'flow_both'.",
            ]
        end
        @testset "Where there are more than one row of data" begin
            # Test 2:
            # For asset and flow
            # Having more than one row of data per milestone year
            DuckDB.query(
                connection,
                """
                INSERT INTO asset_both (asset, milestone_year, commission_year)
                VALUES ('ccgt', 2030, 2030);
                INSERT INTO flow_both (from_asset, to_asset, milestone_year, commission_year)
                VALUES ('wind', 'demand', 2030, 2030);
                """,
            )
            error_messages =
                TEM._validate_simple_method_data_contains_more_than_one_row!(String[], connection)
            @test error_messages == [
                "'ccgt' uses 'none' investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there are 2 rows of data for milestone year 2030 in 'asset_both'.",
                "By default, transport flow ('wind', 'demand') uses simple/none investment method so there should only be one row of data per milestone year (where milestone year equals to commission year), but there are 2 rows of data for milestone year 2030 in 'flow_both'.",
            ]
        end
    end
end
