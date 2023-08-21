using BenchmarkTools
using TulipaBulb

const SUITE = BenchmarkGroup()

SUITE["io"] = BenchmarkGroup(["data", "input", "output"])
SUITE["model"] = BenchmarkGroup(["model"])

const INPUT_FOLDER = joinpath(@__DIR__, "..", "test", "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "..", "test", "outputs")

SUITE["io"]["input"] = @benchmarkable begin
    create_parameters_and_sets_from_file($INPUT_FOLDER)
end
parameters, sets = create_parameters_and_sets_from_file(INPUT_FOLDER)

SUITE["model"]["all"] = @benchmarkable begin
    optimise_investments($parameters, $sets)
end

solution = optimise_investments(parameters, sets)

SUITE["io"]["output"] = @benchmarkable begin
    save_solution_to_file(
        $OUTPUT_FOLDER,
        $(solution.v_investment),
        $(parameters.p_unit_capacity),
    )
end
