@testset "Testing Model Parameters" begin
    path = joinpath(@__DIR__, "inputs", "model-parameters-example.toml")

    @testset "Basic usage" begin
        mp = TulipaEnergyModel.ModelParameters(;
            discount_rate = 0.1,
            discount_year = 2018,
            power_system_base = 50,
        )
        @test mp.discount_rate == 0.1
        @test mp.discount_year == 2018
        @test mp.power_system_base == 50
    end

    @testset "Errors when missing required parameters" begin
        @test_throws UndefKeywordError TulipaEnergyModel.ModelParameters()
    end

    @testset "Read from file" begin
        mp = TulipaEnergyModel.ModelParameters(path)
        data = TOML.parsefile(path)
        for (key, value) in data
            @test value == getfield(mp, Symbol(key))
        end

        @testset "explicit keywords take precedence" begin
            mp = TulipaEnergyModel.ModelParameters(path; discount_year = 2019)
            @test mp.discount_year == 2019
        end

        @testset "Errors if path does not exist" begin
            @test_throws ArgumentError TulipaEnergyModel.ModelParameters("nonexistent.toml")
        end
    end

    @testset "Read from DuckDB" begin
        connection = DBInterface.connect(DuckDB.DB)
        TulipaIO.read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Norse"))
        mp = TulipaEnergyModel.ModelParameters(connection)
        @test mp.discount_year == 2030

        @testset "path has precedence" begin
            mp = TulipaEnergyModel.ModelParameters(connection, path)
            data = TOML.parsefile(path)
            for (key, value) in data
                @test value == getfield(mp, Symbol(key))
            end
        end

        @testset "explicit keywords take precedence" begin
            mp = TulipaEnergyModel.ModelParameters(connection, path; discount_year = 2019)
            @test mp.discount_year == 2019
        end
    end
end
