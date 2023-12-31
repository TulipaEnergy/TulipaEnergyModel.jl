@testset "Test that solve_model! throws if model is not created but works otherwise" begin
    energy_problem = create_energy_problem_from_csv_folder(joinpath(INPUT_FOLDER, "Tiny"))
    @test_throws Exception solve_model!(energy_problem)
    @test !energy_problem.solved
    create_model!(energy_problem)
    @test !energy_problem.solved
    solution = solve_model!(energy_problem)
    @test energy_problem.solved
end
