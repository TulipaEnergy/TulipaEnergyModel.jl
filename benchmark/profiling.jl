#%% See instructions on profiling in the README.dev.md

using TulipaEnergyModel
using BenchmarkTools

const NORSE_PATH = joinpath(@__DIR__, "../test/inputs/Norse")

# Modification of Norse to make it harder:
new_rp_length = 8760
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

#%%

@time graph, representative_periods =
    create_graph_and_representative_periods_from_csv_folder(input_dir);
@benchmark create_graph_and_representative_periods_from_csv_folder($input_dir)
# @profview create_graph_and_representative_periods_from_csv_folder(input_dir);

#%%
constraints_partitions = Dict{String,Dict{Tuple{String,Int},Vector{TimeBlock}}}()

@time constraints_partitions["lowest_resolution"] =
    compute_constraints_partitions(graph, representative_periods; strategy = :greedy);
@benchmark compute_constraints_partitions($graph, $representative_periods; strategy = :greedy)
# @profview compute_constraints_partitions(graph, representative_periods; strategy = :greedy);

#%%

@time constraints_partitions["highest_resolution"] =
    compute_constraints_partitions(graph, representative_periods; strategy = :all);
@benchmark compute_constraints_partitions($graph, $representative_periods; strategy = :all)
# @profview compute_constraints_partitions(graph, representative_periods; strategy = :all);

#%%

@time model = create_model(graph, representative_periods, constraints_partitions);
@benchmark create_model($graph, $representative_periods, $constraints_partitions)
# @profview create_model(graph, representative_periods, constraints_partitions);
