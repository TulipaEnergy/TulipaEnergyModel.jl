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

@testitem "Test model parameters - table missing" setup = [CommonSetup, ModelParametersSetup] tags =
    [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    # populate_with_defaults! should do nothing silently if the table doesn't exist
    TulipaEnergyModel.populate_with_defaults!(connection)
    @test_throws Exception DuckDB.query(connection, "SELECT * FROM model_parameters")

    # we should be able to create the model_parameters table with defaults
    TulipaEnergyModel._create_model_parameters_unless_exists!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.0
    @test mp.discount_year == 9999
    @test mp.power_system_base == 100.0
    @test mp.risk_aversion_confidence_level_alpha == 0.95
    @test mp.risk_aversion_weight_lambda == 0.0
end

@testitem "Test model parameters - table exists but only has headers" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()

    create_model_parameters_table!(connection;)

    # below functions should do nothing silently if the table exists but has no data
    TulipaEnergyModel.populate_with_defaults!(connection)
    TulipaEnergyModel._create_model_parameters_unless_exists!(connection)

    mp = collect(DuckDB.query(connection, "SELECT * FROM model_parameters"))
    @test length(mp) == 0
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

@testitem "Test model parameters - if discount_year is missing" setup =
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

    # using populate_with_defaults! should fill in the missing discount_year with the default value
    TulipaEnergyModel.populate_with_defaults!(connection)
    mp = query_model_parameters(connection)

    @test mp.discount_rate == 0.03
    @test mp.discount_year == 9999
    @test mp.power_system_base == 80.0
    @test mp.risk_aversion_confidence_level_alpha == 0.8
    @test mp.risk_aversion_weight_lambda == 0.2

    # discount_year should be clamped to the earliest milestone year, which is 2030 in the Norse dataset
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    mp = query_model_parameters(connection)
    @test mp.discount_year == 2030
end

# We do two validations for model_parameters in data_validation!:
# 1) We check that the table has exactly one row
# 2) We check that if discount_year is given, then it is the earliest milestone year or earlier.
