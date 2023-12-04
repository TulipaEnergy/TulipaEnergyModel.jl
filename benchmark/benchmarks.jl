using BenchmarkTools
using TulipaEnergyModel
using MetaGraphsNext

const SUITE = BenchmarkGroup()
const NORSE_PATH = joinpath(@__DIR__, "../test/inputs/Norse")

# The following lines are checking whether this is being called from the `test`.
# If it is not, then we create a larger dataset
const INPUT_FOLDER_BM = if isdefined(Main, :Test)
    NORSE_PATH
else
    # Copy Norse
    new_rp_length = 365 * 4
    input_dir = mktempdir()
    for file in readdir(NORSE_PATH; join = false)
        cp(joinpath(NORSE_PATH, file), joinpath(input_dir, file))
    end
    # Add another line to rep-periods-data.csv
    open(joinpath(input_dir, "rep-periods-data.csv"), "a") do io
        println(io, "3,1,$new_rp_length,0.1")
    end
    # Add profiles to flow and asset
    open(joinpath(input_dir, "flows-profiles.csv"), "a") do io
        for (u, v) in [("Asgard_E_demand", "Valhalla_E_balance")]
            for i = 1:new_rp_length
                println(io, "$u,$v,3,$i,0.95")
            end
        end
    end
    open(joinpath(input_dir, "assets-profiles.csv"), "a") do io
        for a in ["Asgard_E_demand"]
            for i = 1:new_rp_length
                println(io, "$a,3,$i,0.95")
            end
        end
    end
    new_input_folder
end

const OUTPUT_FOLDER_BM = mktempdir()

SUITE["direct_usage"] = BenchmarkGroup()
SUITE["direct_usage"]["input"] = @benchmarkable begin
    create_graph_and_representative_periods_from_csv_folder($INPUT_FOLDER_BM)
end
graph, representative_periods =
    create_graph_and_representative_periods_from_csv_folder(INPUT_FOLDER_BM)

SUITE["direct_usage"]["constraints_partitions"] = @benchmarkable begin
    compute_constraints_partitions($graph, $representative_periods)
end
constraints_partitions = compute_constraints_partitions(graph, representative_periods)

SUITE["direct_usage"]["create_model"] = @benchmarkable begin
    create_model($graph, $representative_periods, $constraints_partitions)
end
model = create_model(graph, representative_periods, constraints_partitions)

# SUITE["direct_usage"]["solve_model"] = @benchmarkable begin
#     solve_model($model)
# end
# solution = solve_model(model)

# SUITE["direct_usage"]["output"] = @benchmarkable begin
#     save_solution_to_file($OUTPUT_FOLDER_BM, $graph)
# end

SUITE["energy_problem"] = BenchmarkGroup()
SUITE["energy_problem"]["input_and_constructor"] = @benchmarkable begin
    create_energy_problem_from_csv_folder($INPUT_FOLDER_BM)
end
energy_problem = create_energy_problem_from_csv_folder(INPUT_FOLDER_BM)

SUITE["energy_problem"]["create_model"] = @benchmarkable begin
    create_model!($energy_problem)
end
create_model!(energy_problem)

# SUITE["energy_problem"]["solve_model"] = @benchmarkable begin
#     solve_model!($energy_problem)
# end
# solve_model!(energy_problem)

# SUITE["energy_problem"]["output"] = @benchmarkable begin
#     save_solution_to_file($OUTPUT_FOLDER_BM, $energy_problem)
# end
