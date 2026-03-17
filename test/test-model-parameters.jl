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
    )
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TABLE model_parameters (
                discount_rate DOUBLE,
                discount_year INTEGER,
                power_system_base DOUBLE
            );
            """,
        )

        # Build a data frame with non-missing values only
        data_dict = Dict{Symbol,Vector}()
        !ismissing(discount_rate) && (data_dict[:discount_rate] = [discount_rate])
        !ismissing(discount_year) && (data_dict[:discount_year] = [discount_year])
        !ismissing(power_system_base) && (data_dict[:power_system_base] = [power_system_base])

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

    mp = TulipaEnergyModel.ModelParameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2020
    @test mp.power_system_base == 90.0
    @test mp.risk_aversion_confidence_level_alpha == 0.90
    @test mp.risk_aversion_weight_lambda == 0.1
end

@testitem "Test model parameters - uses default values when table is missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    mp = TulipaEnergyModel.ModelParameters(connection)

    @test mp.discount_rate == 0.0
    @test mp.discount_year == 2030
    @test mp.power_system_base == 100.0
end

@testitem "Test model parameters - uses milestone default if discount_year is missing" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    create_model_parameters_table!(
        connection;
        discount_rate = 0.03,
        discount_year = missing,
        power_system_base = 80.0,
    )

    mp = TulipaEnergyModel.ModelParameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 2030
    @test mp.power_system_base == 80.0
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
            (0.03, 2020, 100.0),
            (0.04, 2030, 110.0)
        ) AS t(discount_rate, discount_year, power_system_base)
        """,
    )

    @test_throws Exception TulipaEnergyModel.ModelParameters(connection)
end
