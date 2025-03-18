const TEM = TulipaEnergyModel

@testset "Test DataValidationException print" begin
    # Mostly to appease codecov
    error_msg = "DataValidationException: The following issues were found in the data:\n- example"
    @test_throws error_msg throw(TEM.DataValidationException(["example"]))
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

        # Modify group value to bad value
        DuckDB.query(connection, "UPDATE asset SET \"group\" = 'bad' WHERE asset = 'ccgt'")
        @test_throws "Table 'asset' column 'group' has invalid value 'bad'. Valid values should be among column 'name' of 'group_asset'" TEM.create_internal_tables!(
            connection,
        )
    end
end
