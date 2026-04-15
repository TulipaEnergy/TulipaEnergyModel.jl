@testsnippet ModelParametersSetup begin
    function create_model_parameters_table!(
        connection;
        discount_rate = "NULL",
        discount_year = "NULL",
        power_system_base = "NULL",
        risk_aversion_confidence_level_alpha = "NULL",
        risk_aversion_weight_lambda = "NULL",
    )
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE model_parameters (
                discount_rate DOUBLE,
                discount_year INTEGER,
                power_system_base DOUBLE,
                risk_aversion_confidence_level_alpha DOUBLE,
                risk_aversion_weight_lambda DOUBLE
            );
            """,
        )
        # if default values are provided, we only give the headers
        if any(
            v -> v != "NULL",
            (
                discount_rate,
                discount_year,
                power_system_base,
                risk_aversion_confidence_level_alpha,
                risk_aversion_weight_lambda,
            ),
        )
            DuckDB.query(
                connection,
                """
                INSERT INTO model_parameters VALUES (
                    $discount_rate, $discount_year, $power_system_base,
                    $risk_aversion_confidence_level_alpha, $risk_aversion_weight_lambda
                )
                """,
            )
        end
        return nothing
    end

    function query_model_parameters(connection)
        return only(collect(DuckDB.query(connection, "SELECT * FROM model_parameters")))
    end
end

@testitem "Test model parameters - table missing" setup = [CommonSetup, ModelParametersSetup] tags =
    [:unit, :validation, :fast] begin
    connection = _Norse_fixture()

    # Norse has the table, so drop it first
    DuckDB.query(connection, "DROP TABLE IF EXISTS model_parameters")
    @test !TulipaEnergyModel._check_if_table_exists(connection, "model_parameters")

    TulipaEnergyModel.populate_with_defaults!(connection)

    mp = query_model_parameters(connection)

    # discount_year should be calculated as the earliest milestone year, which is 2030 in the Norse dataset
    @test mp.discount_year == 2030
    # all the other parameters should be filled with default values
    @test mp.discount_rate == 0.0
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - empty table, i.e., exists but only has headers" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()

    # Norse has the table, so drop it first
    DuckDB.query(connection, "DROP TABLE IF EXISTS model_parameters")
    @test !TulipaEnergyModel._check_if_table_exists(connection, "model_parameters")
    # create the table but don't insert any values, so it only has headers
    create_model_parameters_table!(connection;)
    @test TulipaEnergyModel._check_if_table_exists(connection, "model_parameters")
    @test TulipaEnergyModel.count_rows_from(connection, "model_parameters") == 0

    TulipaEnergyModel.populate_with_defaults!(connection)

    mp = query_model_parameters(connection)

    # discount_year should be calculated as the earliest milestone year, which is 2030 in the Norse dataset
    @test mp.discount_year == 2030
    # all the other parameters should be filled with default values
    @test mp.discount_rate == 0.0
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - read from model_parameters table" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        discount_year = 2020,
        power_system_base = 90.0,
        risk_aversion_confidence_level_alpha = 0.90,
        risk_aversion_weight_lambda = 0.1,
    )

    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2020
    @test mp.power_system_base == 90.0
    @test mp.risk_aversion_confidence_level_alpha == 0.90
    @test mp.risk_aversion_weight_lambda == 0.1
end

@testitem "Test model parameters - if discount_year value is NULL" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        power_system_base = 80.0,
        risk_aversion_confidence_level_alpha = 0.8,
        risk_aversion_weight_lambda = 0.2,
    )

    # using populate_with_defaults! should fill in the missing discount_year with the calculated value based on the earliest milestone year,
    # which is 2030 in the Norse dataset
    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.8
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - if discount_year column is entirely absent" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    DuckDB.query(connection, "DROP TABLE IF EXISTS model_parameters")
    DuckDB.query(
        connection,
        "CREATE TABLE model_parameters AS
        SELECT * FROM (VALUES
            (0.03, 80.0, 0.8, 0.2)
        ) AS t(discount_rate, power_system_base, risk_aversion_confidence_level_alpha, risk_aversion_weight_lambda)",
    )
    cols = [
        row.column_name for row in DuckDB.query(
            connection,
            "SELECT column_name FROM duckdb_columns() WHERE table_name = 'model_parameters'",
        )
    ]
    @test !("discount_year" in cols)

    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.8
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - if other parameters are missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    create_model_parameters_table!(
        connection;
        discount_year = 2025, # this should be used instead of the calculated 2030 since it's not missing
        power_system_base = 80.0,
        risk_aversion_weight_lambda = 0.2,
    )

    # using populate_with_defaults! should fill in the missing discount_rate with the default value,
    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.0
    # discount_year should be the value given in the table, since it's not missing
    @test mp.discount_year == 2025
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - check calculation logic of discount_year if missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _multi_year_fixture()
    # set discount_year to missing
    DuckDB.query(connection, "UPDATE model_parameters SET discount_year = NULL")

    # using populate_with_defaults! should calculate the missing discount_year based on the earliest milestone year, which is 2030 in the Multi-year Investments dataset
    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    # discount_year should be the value given in the table, since it's not missing
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - empty table without discount_year column" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    DuckDB.query(connection, "DROP TABLE IF EXISTS model_parameters")
    # Table exists with only 4 columns (no discount_year) and 0 rows
    # exercises the _rebuild_table_with_defaults! code path followed by ALTER ADD COLUMN + INSERT DEFAULT VALUES + UPDATE.
    DuckDB.query(
        connection,
        "CREATE TABLE model_parameters (
            discount_rate DOUBLE,
            power_system_base DOUBLE,
            risk_aversion_confidence_level_alpha DOUBLE,
            risk_aversion_weight_lambda DOUBLE
        )",
    )
    @test TulipaEnergyModel.count_rows_from(connection, "model_parameters") == 0

    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.0
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - populate won't overwrite fully-valid input" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = _Norse_fixture()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        discount_year = 2020,
        power_system_base = 90.0,
        risk_aversion_confidence_level_alpha = 0.90,
        risk_aversion_weight_lambda = 0.1,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2020
    @test mp.power_system_base == 90.0
    @test mp.risk_aversion_confidence_level_alpha == 0.90
    @test mp.risk_aversion_weight_lambda == 0.1
end
