@testset "Test missing defaults and populate_with_defaults!" begin
    @testset "From the basic data" begin
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

    @testset "Test that Tiny has all default data and calling populate won't break it" begin
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

    @testset "Test 1 missing column in Tiny" begin
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

    @testset "Test that missing column cannot be require" begin
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
end
