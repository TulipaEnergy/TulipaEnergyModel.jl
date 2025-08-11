@testsnippet ModelParametersSetup begin
    const TOML_PATH = joinpath(@__DIR__, "inputs", "model-parameters-example.toml")
    const NORSE_PATH = joinpath(@__DIR__, "inputs", "Norse")

    function connection_with_norse()
        connection = DBInterface.connect(DuckDB.DB)
        TulipaIO.read_csv_folder(connection, NORSE_PATH)
        return connection
    end

    function validate_toml_matches_mp(mp, toml_path)
        data = TOML.parsefile(toml_path)
        for (key, value) in data
            @test value == getfield(mp, Symbol(key))
        end
    end
end

@testitem "Test model parameters - basic usage" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    mp = TulipaEnergyModel.ModelParameters(;
        discount_rate = 0.1,
        discount_year = 2018,
        power_system_base = 50,
    )
    @test mp.discount_rate == 0.1
    @test mp.discount_year == 2018
    @test mp.power_system_base == 50
end

@testitem "Test model parameters - errors when missing required parameters" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    @test_throws UndefKeywordError TulipaEnergyModel.ModelParameters()
end

@testitem "Test model parameters - read from file" setup = [CommonSetup, ModelParametersSetup] tags =
    [:unit, :validation, :fast] begin
    mp = TulipaEnergyModel.ModelParameters(TOML_PATH)
    validate_toml_matches_mp(mp, TOML_PATH)
end

@testitem "Test model parameters - explicit keywords take precedence" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    mp = TulipaEnergyModel.ModelParameters(TOML_PATH; discount_year = 2019)
    @test mp.discount_year == 2019
end

@testitem "Test model parameters - errors if path does not exist" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    @test_throws ArgumentError TulipaEnergyModel.ModelParameters("nonexistent.toml")
end

@testitem "Test model parameters - read from DuckDB" setup = [CommonSetup, ModelParametersSetup] tags =
    [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    mp = TulipaEnergyModel.ModelParameters(connection)
    @test mp.discount_year == 2030
end

@testitem "Test model parameters - path has precedence over DuckDB" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    mp = TulipaEnergyModel.ModelParameters(connection, TOML_PATH)
    validate_toml_matches_mp(mp, TOML_PATH)
end

@testitem "Test model parameters - explicit keywords take precedence over DuckDB and path" setup =
    [CommonSetup, ModelParametersSetup] tags = [:unit, :validation, :fast] begin
    connection = connection_with_norse()
    mp = TulipaEnergyModel.ModelParameters(connection, TOML_PATH; discount_year = 2019)
    @test mp.discount_year == 2019
end
