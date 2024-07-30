@testset "Test some HiGHS options" begin
    connection = DBInterface.connect(DuckDB.DB)
    read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = run_scenario(
        connection;
        output_folder = OUTPUT_FOLDER,
        optimizer = HiGHS.Optimizer,
        parameters = Dict(
            "output_flag" => false,
            "dual_feasibility_tolerance" => 1e-4,
            "mip_rel_gap" => 1e-2,
            "mip_abs_gap" => 1e-4,
            "mip_max_leaves" => 64,
        ),
        write_lp_file = true,
    )
end

@testset "Test default_parameters usage" begin
    @testset "HiGHS" begin
        expected = Dict{String,Any}("output_flag" => false)
        @test default_parameters(Val(:HiGHS)) == expected
        @test default_parameters(HiGHS.Optimizer) == expected
        @test default_parameters(:HiGHS) == expected
        @test default_parameters("HiGHS") == expected
    end

    @testset "Undefined values" begin
        expected = Dict{String,Any}()
        @test default_parameters(Val(:blah)) == expected
        @test default_parameters(:blah) == expected
        @test default_parameters("blah") == expected
        struct DummySolver <: MathOptInterface.AbstractOptimizer end
        @test default_parameters(Val(:DummySolver)) == expected
    end

    @testset "New definition" begin
        expected = Dict{String,Any}("dummy" => true, "use" => :testing)
        struct NewSolver <: MathOptInterface.AbstractOptimizer end
        TulipaEnergyModel.default_parameters(::Val{:NewSolver}) = expected
        @test TulipaEnergyModel.default_parameters(NewSolver) == expected
        @test TulipaEnergyModel.default_parameters(:NewSolver) == expected
        @test TulipaEnergyModel.default_parameters("NewSolver") == expected
    end
end

@testset "Test reading from file" begin
    filepath, io = mktemp()
    println(
        io,
        """
            true_or_false = true
            integer_number = 5
            real_number1 = 3.14
            big_number = 6.66E06
            small_number = 1e-8
            string = "something"
        """,
    )
    close(io)

    @test read_parameters_from_file(filepath) == Dict{String,Any}(
        "string"         => "something",
        "integer_number" => 5,
        "small_number"   => 1.0e-8,
        "true_or_false"  => true,
        "real_number1"   => 3.14,
        "big_number"     => 6.66e6,
    )

    @test_throws ArgumentError read_parameters_from_file("badfile")
end

@testset "Test that bad options throw errors" begin
    connection = DBInterface.connect(DuckDB.DB)
    read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    @test_throws MathOptInterface.UnsupportedAttribute energy_problem = run_scenario(
        connection;
        output_folder = OUTPUT_FOLDER,
        optimizer = HiGHS.Optimizer,
        parameters = Dict("bad_param" => 1.0),
    )
end
