@testset "Test some HiGHS options" begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.run_scenario(
        connection;
        output_folder = OUTPUT_FOLDER,
        optimizer = HiGHS.Optimizer,
        optimizer_parameters = Dict(
            "output_flag" => false,
            "dual_feasibility_tolerance" => 1e-4,
            "mip_rel_gap" => 1e-2,
            "mip_abs_gap" => 1e-4,
            "mip_max_leaves" => 64,
        ),
        model_file_name = "model.lp",
        show_log = false,
    )
end

@testset "Test run_scenario arguments" begin
    connection = _tiny_fixture()

    ep = TulipaEnergyModel.run_scenario(
        connection;
        output_folder = OUTPUT_FOLDER,
        optimizer = GLPK.Optimizer,
        optimizer_parameters = Dict("msg_lev" => GLPK.GLP_MSG_OFF, "tol_int" => 1e-3),
        model_file_name = "model.lp",
        enable_names = false,
        direct_model = true,
        log_file = "model.log",
        show_log = false,
    )

    @test JuMP.get_attribute(ep.model, "msg_lev") == GLPK.GLP_MSG_OFF
    @test JuMP.get_attribute(ep.model, "tol_int") == 1e-3
    @test JuMP.constraint_by_name(ep.model, "consumer_balance[demand,2030,1,1:1]") === nothing
    @test JuMP.mode(ep.model) == JuMP.ModelMode(2)
end

@testset "Test create_model! arguments" begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))

    ep = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(
        ep;
        optimizer = GLPK.Optimizer,
        optimizer_parameters = Dict("msg_lev" => GLPK.GLP_MSG_OFF, "tol_int" => 1e-3),
        enable_names = false,
        direct_model = true,
    )

    @test JuMP.get_attribute(ep.model, "msg_lev") == GLPK.GLP_MSG_OFF
    @test JuMP.get_attribute(ep.model, "tol_int") == 1e-3
    @test JuMP.constraint_by_name(ep.model, "consumer_balance[demand,2030,1,1:1]") === nothing
    @test JuMP.mode(ep.model) == JuMP.ModelMode(2)
end

@testset "Test default_parameters usage" begin
    @testset "HiGHS" begin
        expected = Dict{String,Any}("output_flag" => false)
        @test TulipaEnergyModel.default_parameters(Val(:HiGHS)) == expected
        @test TulipaEnergyModel.default_parameters(HiGHS.Optimizer) == expected
        @test TulipaEnergyModel.default_parameters(:HiGHS) == expected
        @test TulipaEnergyModel.default_parameters("HiGHS") == expected
    end

    @testset "Undefined values" begin
        expected = Dict{String,Any}()
        @test TulipaEnergyModel.default_parameters(Val(:blah)) == expected
        @test TulipaEnergyModel.default_parameters(:blah) == expected
        @test TulipaEnergyModel.default_parameters("blah") == expected
        struct DummySolver <: MathOptInterface.AbstractOptimizer end
        @test TulipaEnergyModel.default_parameters(Val(:DummySolver)) == expected
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

    @test TulipaEnergyModel.read_parameters_from_file(filepath) == Dict{String,Any}(
        "string"         => "something",
        "integer_number" => 5,
        "small_number"   => 1.0e-8,
        "true_or_false"  => true,
        "real_number1"   => 3.14,
        "big_number"     => 6.66e6,
    )

    @test_throws ArgumentError TulipaEnergyModel.read_parameters_from_file("badfile")
end

@testset "Test that bad options throw errors" begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    @test_throws MathOptInterface.UnsupportedAttribute energy_problem =
        TulipaEnergyModel.run_scenario(
            connection;
            output_folder = OUTPUT_FOLDER,
            optimizer = HiGHS.Optimizer,
            optimizer_parameters = Dict("bad_param" => 1.0),
            show_log = false,
        )
end
