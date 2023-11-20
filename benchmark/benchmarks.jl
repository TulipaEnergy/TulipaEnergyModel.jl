using BenchmarkTools
using TulipaEnergyModel
using MetaGraphsNext

const SUITE = BenchmarkGroup()

SUITE["io"] = BenchmarkGroup()
SUITE["model"] = BenchmarkGroup()

const INPUT_FOLDER_BM = joinpath(@__DIR__, "..", "test", "inputs", "Norse")
const OUTPUT_FOLDER_BM = mktempdir()

SUITE["io"]["input"] = @benchmarkable begin
    create_energy_model_from_csv_folder($INPUT_FOLDER_BM)
end
energy_model = create_energy_model_from_csv_folder(INPUT_FOLDER_BM)

SUITE["model"]["create_model"] = @benchmarkable begin
    create_model($energy_model)
end

model = create_model(energy_model)

SUITE["model"]["solve_model"] = @benchmarkable begin
    solve_model($model)
end

solution = solve_model(model)

SUITE["io"]["output"] = @benchmarkable begin
    save_solution_to_file(
        $OUTPUT_FOLDER_BM,
        $([a for a in labels(energy_model.graph) if energy_model.graph[a].investable]),
        $(solution.assets_investment),
        $(Dict(a => energy_model.graph[a].capacity for a in labels(energy_model.graph))),
    )
end
