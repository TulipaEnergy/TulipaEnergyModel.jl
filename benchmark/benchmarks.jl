using BenchmarkTools
using TulipaEnergyModel
using MetaGraphsNext

const SUITE = BenchmarkGroup()

SUITE["io"] = BenchmarkGroup()
SUITE["model"] = BenchmarkGroup()

const INPUT_FOLDER_BM = joinpath(@__DIR__, "..", "test", "inputs", "Norse")
const OUTPUT_FOLDER_BM = mktempdir()

SUITE["io"]["input"] = @benchmarkable begin
    create_energy_problem_from_csv_folder($INPUT_FOLDER_BM)
end
energy_problem = create_energy_problem_from_csv_folder(INPUT_FOLDER_BM)

SUITE["model"]["create_model"] = @benchmarkable begin
    create_model($energy_problem)
end

model = create_model(energy_problem)

SUITE["model"]["solve_model"] = @benchmarkable begin
    solve_model($model)
end

solution = solve_model(model)

SUITE["io"]["output"] = @benchmarkable begin
    save_solution_to_file(
        $OUTPUT_FOLDER_BM,
        $([a for a in labels(energy_problem.graph) if energy_problem.graph[a].investable]),
        $(solution.assets_investment),
        $(Dict(a => energy_problem.graph[a].capacity for a in labels(energy_problem.graph))),
    )
end
