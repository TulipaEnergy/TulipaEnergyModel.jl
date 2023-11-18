using BenchmarkTools
using TulipaEnergyModel
using MetaGraphsNext

const SUITE = BenchmarkGroup()

SUITE["io"] = BenchmarkGroup()
SUITE["model"] = BenchmarkGroup()

const INPUT_FOLDER_BM = joinpath(@__DIR__, "..", "test", "inputs", "Norse")
const OUTPUT_FOLDER_BM = mktempdir()

SUITE["io"]["input"] = @benchmarkable begin
    create_parameters_and_sets_from_file($INPUT_FOLDER_BM)
end
graph, representative_periods = create_parameters_and_sets_from_file(INPUT_FOLDER_BM)

SUITE["model"]["create_model"] = @benchmarkable begin
    create_model($graph, $representative_periods)
end

model = create_model(graph, representative_periods)

SUITE["model"]["solve_model"] = @benchmarkable begin
    solve_model($model)
end

solution = solve_model(model)

SUITE["io"]["output"] = @benchmarkable begin
    save_solution_to_file(
        $OUTPUT_FOLDER_BM,
        $([a for a in labels(graph) if graph[a].investable]),
        $(solution.assets_investment),
        $(Dict(a => graph[a].capacity for a in labels(graph))),
    )
end
