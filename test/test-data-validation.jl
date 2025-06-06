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
        @test TEM._validate_no_duplicate_rows!(connection, "bad_data", [:asset]) |> sort == [
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
        @testset "Where there is data for milestone year != commission year" begin
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

            error_messages =
                TEM._validate_simple_method_has_only_matching_years!(String[], connection)
            @test error_messages == [
                "Unexpected (asset='A1', milestone_year=1, commission_year=0) in 'asset_both' for an asset='A1' with investment_method='simple'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
                "Unexpected (asset='A2', milestone_year=1, commission_year=0) in 'asset_both' for an asset='A2' with investment_method='none'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
                "Unexpected (from_asset='A2', to_asset='B', milestone_year=1, commission_year=0) in 'flow_both' for an flow=('A2', 'B') with default investment_method='simple/none'. For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
            ]
        end

        @testset "Where not all milestone years are covered" begin
            # For asset and flow
            # Validate that the data contains all milestone years where milestone year = commission year
            # Error otherwise and point out the missing milestone years
            connection = DBInterface.connect(DuckDB.DB)
            asset = DataFrame(:asset => ["A1", "A2"], :investment_method => ["simple", "none"])
            asset_milestone = DataFrame(:asset => ["A1", "A2"], :milestone_year => [1, 1])
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
            flow_milestone = DataFrame(
                :from_asset => ["A1", "A2"],
                :to_asset => ["B", "B"],
                :milestone_year => [1, 1],
            )
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
    end

    @testset "Using Tiny data" begin
        @testset "Where there is data for milestone year != commission year" begin
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
            error_messages =
                TEM._validate_simple_method_has_only_matching_years!(String[], connection)
            @test error_messages == [
                "Unexpected (asset='ccgt', milestone_year=2030, commission_year=2029) in 'asset_both' for an asset='ccgt' with investment_method='simple'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
                "Unexpected (from_asset='wind', to_asset='demand', milestone_year=2030, commission_year=2029) in 'flow_both' for an flow=('wind', 'demand') with default investment_method='simple/none'. For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
            ]
        end
        @testset "Where not all milestone years are covered" begin
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
    end
end

@testset "Check investable storage with binary method has investment limit > 0" begin
    @testset "Using fake data" begin
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
            "Incorrect investment_limit = missing for investable storage asset 'storage_1' with use_binary_storage_method = 'binary' for year 1. The investment_limit at year 1 should be greater than 0 in 'asset_commission'.",
            "Incorrect investment_limit = 0 for investable storage asset 'storage_2' with use_binary_storage_method = 'binary' for year 1. The investment_limit at year 1 should be greater than 0 in 'asset_commission'.",
        ]
    end
    @testset "Using Storage data" begin
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
            "Incorrect investment_limit = missing for investable storage asset 'battery' with use_binary_storage_method = 'binary' for year 2030. The investment_limit at year 2030 should be greater than 0 in 'asset_commission'.",
        ]
    end
end
@testset "Check DC OPF data" begin
    @testset "Using fake data" begin
        @testset "Reactance > 0" begin
            connection = DBInterface.connect(DuckDB.DB)
            flow_milestone = DataFrame(
                :from_asset => ["A", "A", "A"],
                :to_asset => ["B", "B", "B"],
                :milestone_year => [1, 2, 3],
                :reactance => [1.0, 0.0, -1.0],
            )
            DuckDB.register_data_frame(connection, flow_milestone, "flow_milestone")
            error_messages =
                TEM._validate_reactance_must_be_greater_than_zero!(String[], connection)
            @test error_messages == [
                "Incorrect reactance = 0.0 for flow ('A', 'B') for year 2 in 'flow_milestone'. The reactance should be greater than 0.",
                "Incorrect reactance = -1.0 for flow ('A', 'B') for year 3 in 'flow_milestone'. The reactance should be greater than 0.",
            ]
        end
        @testset "Only apply to non-investable transport flows" begin
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
            error_messages = TEM._validate_dc_opf_only_apply_to_non_investable_transport_flows!(
                String[],
                connection,
            )
            @test error_messages == [
                "Incorrect use of dc-opf method for flow ('A', 'B') for year 2 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
                "Incorrect use of dc-opf method for flow ('B', 'C') for year 1 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
            ]
        end
    end
    @testset "Using Tiny data" begin
        @testset "Reactance > 0" begin
            connection = _tiny_fixture()
            DuckDB.query(
                connection,
                """
                UPDATE flow_milestone SET reactance = 0.0 WHERE from_asset = 'wind' and to_asset = 'demand';
                UPDATE flow_milestone SET reactance = -1.0 WHERE from_asset = 'solar' and to_asset = 'demand';
                """,
            )
            error_messages =
                TEM._validate_reactance_must_be_greater_than_zero!(String[], connection)
            @test error_messages == [
                "Incorrect reactance = 0.0 for flow ('wind', 'demand') for year 2030 in 'flow_milestone'. The reactance should be greater than 0.",
                "Incorrect reactance = -1.0 for flow ('solar', 'demand') for year 2030 in 'flow_milestone'. The reactance should be greater than 0.",
            ]
        end
        @testset "Only apply to non-investable transport flows" begin
            connection = _tiny_fixture()
            DuckDB.query(
                connection,
                """
                UPDATE flow SET is_transport = true WHERE from_asset = 'wind' and to_asset = 'demand';
                UPDATE flow_milestone SET dc_opf = true, investable = true WHERE from_asset = 'wind' and to_asset = 'demand';
                UPDATE flow_milestone SET dc_opf = true, investable = false WHERE from_asset = 'solar' and to_asset = 'demand';
                """,
            )
            error_messages = TEM._validate_dc_opf_only_apply_to_non_investable_transport_flows!(
                String[],
                connection,
            )
            @test error_messages == [
                "Incorrect use of dc-opf method for flow ('wind', 'demand') for year 2030 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
                "Incorrect use of dc-opf method for flow ('solar', 'demand') for year 2030 in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
            ]
        end
    end
end
