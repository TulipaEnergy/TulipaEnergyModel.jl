const TEM = TulipaEnergyModel

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
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Tiny"))
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
