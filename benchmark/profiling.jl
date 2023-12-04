#%% See instructions on profiling in the README.dev.md

using TulipaEnergyModel
using BenchmarkTools

const NORSE_PATH = joinpath(@__DIR__, "../test/inputs/Norse")
input_dir = NORSE_PATH

# For a larger test, uncomment below:
# input_dir = mktempdir()
# for file in readdir(NORSE_PATH; join = false)
#     cp(joinpath(NORSE_PATH, file), joinpath(input_dir, file))
# end
# # Add another line to rep-periods-data.csv
# open(joinpath(input_dir, "rep-periods-data.csv"), "a") do io
#     println(io, "3,1,1000,0.1")
# end

#%%

@time graph, representative_periods =
    create_graph_and_representative_periods_from_csv_folder(input_dir);
@benchmark create_graph_and_representative_periods_from_csv_folder($input_dir)
# @profview create_graph_and_representative_periods_from_csv_folder(input_dir);

#%%

@time constraints_partitions = compute_constraints_partitions(graph, representative_periods);
@benchmark compute_constraints_partitions($graph, $representative_periods)
# @profview compute_constraints_partitions(graph, representative_periods);

#%%

@time model = create_model(graph, representative_periods, constraints_partitions);
@benchmark create_model($graph, $representative_periods, $constraints_partitions)
# @profview create_model(graph, representative_periods, constraints_partitions);
