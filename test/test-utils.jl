@testitem "Test _create_group_table_if_not_exist" setup = [CommonSetup] tags = [:unit, :fast] begin
    # Test data
    table_name = "test_table"
    connection = DBInterface.connect(DuckDB.DB)
    DuckDB.register_table(
        connection,
        (
            (id = 1, asset = "a", year = 1900),
            (id = 2, asset = "a", year = 2000),
            (id = 3, asset = "b", year = 1900),
            (id = 4, asset = "b", year = 2000),
        ),
        table_name,
    )

    # First, the table does not exist
    grouped_table_name = "grouped_$table_name"
    @test !TulipaEnergyModel._check_if_table_exists(connection, grouped_table_name)

    # Create the table and check content
    TulipaEnergyModel._create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        [:asset],
        [:id, :year],
    )
    @test TulipaEnergyModel._check_if_table_exists(connection, grouped_table_name)
    df = DataFrame(DuckDB.query(connection, "FROM $grouped_table_name")) |> sort
    @test names(df) == ["asset", "id", "year"]
    @test size(df) == (2, 3)
    @test df.asset == ["a", "b"]
    @test df.id == [[1, 2], [3, 4]]
    @test df.year == [[1900, 2000], [1900, 2000]]

    # Run it again with different values to check that it doesn't run
    TulipaEnergyModel._create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        [:year],
        [:id, :asset],
    )
    df = DataFrame(DuckDB.query(connection, "FROM $grouped_table_name")) |> sort
    @test names(df) == ["asset", "id", "year"]
    @test size(df) == (2, 3)
    @test df.asset == ["a", "b"]
    @test df.id == [[1, 2], [3, 4]]
    @test df.year == [[1900, 2000], [1900, 2000]]

    # Delete table and run with different values
    DuckDB.query(connection, "DROP TABLE $grouped_table_name")
    TulipaEnergyModel._create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        [:year],
        [:id, :asset],
    )
    df = DataFrame(DuckDB.query(connection, "FROM $grouped_table_name")) |> sort
    @test names(df) == ["year", "id", "asset"]
    @test size(df) == (2, 3)
    @test df.year == [1900, 2000]
    @test df.asset == [["a", "b"], ["a", "b"]]
    @test df.id == [[1, 3], [2, 4]]

    # Check failures
    DuckDB.query(connection, "DROP TABLE $grouped_table_name")
    @test_throws "`group_by_columns` cannot be empty" TulipaEnergyModel._create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        [],
        [:id, :asset],
    )
    @test_throws "`array_agg_columns` cannot be empty" TulipaEnergyModel._create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        [:asset],
        [],
    )
end
