using BenchmarkTools
using TulipaEnergyModel

const SUITE = BenchmarkGroup()

SUITE["io"] = BenchmarkGroup()
SUITE["model"] = BenchmarkGroup()

const INPUT_FOLDER = joinpath(@__DIR__, "..", "test", "inputs", "Norse")
const OUTPUT_FOLDER = joinpath(@__DIR__, "..", "test", "outputs")

SUITE["io"]["input"] = @benchmarkable begin
    create_parameters_and_sets_from_file($INPUT_FOLDER)
end
parameters, sets = create_parameters_and_sets_from_file(INPUT_FOLDER)

SUITE["io"]["graph"] = @benchmarkable begin
    create_graph(
        $(joinpath(INPUT_FOLDER, "assets-data.csv")),
        $(joinpath(INPUT_FOLDER, "flows-data.csv")),
    )
end
graph = create_graph(
    joinpath(INPUT_FOLDER, "assets-data.csv"),
    joinpath(INPUT_FOLDER, "flows-data.csv"),
)

SUITE["model"]["create_model"] = @benchmarkable begin
    create_model($graph, $parameters, $sets)
end

model = create_model(graph, parameters, sets)

SUITE["model"]["solve_model"] = @benchmarkable begin
    solve_model($model)
end

solution = solve_model(model)

SUITE["io"]["output"] = @benchmarkable begin
    save_solution_to_file(
        $OUTPUT_FOLDER,
        $(sets.assets_investment),
        $(solution.assets_investment),
        $(parameters.assets_unit_capacity),
    )
end
