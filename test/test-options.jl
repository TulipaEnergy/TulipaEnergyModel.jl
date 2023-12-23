@testset "Test some HiGHS options" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    energy_problem = run_scenario(
        dir,
        OUTPUT_FOLDER;
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

@testset "Test dummy solver" begin
    struct DummySolver <: MathOptInterface.AbstractOptimizer end
    @test TulipaEnergyModel.default_parameters(DummySolver) == Dict{String,Any}()
end

@testset "Test that bad options throw errors" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    @test_throws MathOptInterface.UnsupportedAttribute energy_problem = run_scenario(
        dir,
        OUTPUT_FOLDER;
        optimizer = HiGHS.Optimizer,
        parameters = Dict("bad_param" => 1.0),
    )
end
