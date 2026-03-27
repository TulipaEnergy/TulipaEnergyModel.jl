@testsnippet ModelParametersSetup begin
    const NORSE_PATH = joinpath(@__DIR__, "inputs", "Norse")

    function connection_with_norse()
        connection = DBInterface.connect(DuckDB.DB)
        TulipaIO.read_csv_folder(connection, NORSE_PATH)
        return connection
    end

    function create_model_parameters_table!(
        connection;
        discount_rate = missing,
        discount_year = missing,
        power_system_base = missing,
        risk_aversion_confidence_level_alpha = missing,
        risk_aversion_weight_lambda = missing,
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

        # Build a data frame with non-missing values only
        data_dict = Dict{Symbol,Vector}()
        !ismissing(discount_rate) && (data_dict[:discount_rate] = [discount_rate])
        !ismissing(discount_year) && (data_dict[:discount_year] = [discount_year])
        !ismissing(power_system_base) && (data_dict[:power_system_base] = [power_system_base])
        !ismissing(risk_aversion_confidence_level_alpha) && (
            data_dict[:risk_aversion_confidence_level_alpha] =
                [risk_aversion_confidence_level_alpha]
        )
        !ismissing(risk_aversion_weight_lambda) &&
            (data_dict[:risk_aversion_weight_lambda] = [risk_aversion_weight_lambda])

        if !isempty(data_dict)
            DuckDB.register_data_frame(connection, DataFrame(data_dict), "model_parameters_values")

            # Build column list dynamically for the INSERT statement
            cols = join(String.(keys(data_dict)), ", ")
            DuckDB.query(
                connection,
                """
                INSERT INTO model_parameters($cols)
                SELECT $cols
                FROM model_parameters_values
                """,
            )
        end

        return
    end

    function query_model_parameters(connection)
        return only(collect(DuckDB.query(connection, "SELECT * FROM model_parameters")))
    end
end

@testitem "Test model parameters - read from model_parameters table" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
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

@testitem "Test model parameters - uses default values when table is missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()

    TulipaEnergyModel._create_empty_unless_exists(connection, "model_parameters")
    TulipaEnergyModel._prepare_model_parameters!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.0
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - uses milestone default if discount_year is missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        discount_year = missing,
        power_system_base = 80.0,
        risk_aversion_confidence_level_alpha = 0.8,
        risk_aversion_weight_lambda = 0.2,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    TulipaEnergyModel._prepare_model_parameters!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.8
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - clamps discount_year to earliest milestone year" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        discount_year = 2040,
        power_system_base = 80.0,
        risk_aversion_confidence_level_alpha = 0.8,
        risk_aversion_weight_lambda = 0.2,
    )

    TulipaEnergyModel._prepare_model_parameters!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.8
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - partial table values with missing non-discount fields" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    create_model_parameters_table!(
        connection;
        discount_rate = missing,
        discount_year = 2040,
        power_system_base = missing,
        risk_aversion_confidence_level_alpha = missing,
        risk_aversion_weight_lambda = 0.2,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    TulipaEnergyModel._prepare_model_parameters!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.0
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.2
end

@testitem "Test model parameters - with populate with default values" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE model_parameters AS
        SELECT *
        FROM (VALUES
            (0.03)
        ) AS t(discount_rate);
        """,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    TulipaEnergyModel._prepare_model_parameters!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - errors if model_parameters has more than one row" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE model_parameters AS
        SELECT *
        FROM (VALUES
            (0.03, 2020, 100.0, 0.95, 0.1),
            (0.04, 2030, 110.0, 0.95, 0.1)
        ) AS t(discount_rate, discount_year, power_system_base, risk_aversion_confidence_level_alpha, risk_aversion_weight_lambda);
        """,
    )

    @test_throws Exception TulipaEnergyModel._prepare_model_parameters!(connection)
end
