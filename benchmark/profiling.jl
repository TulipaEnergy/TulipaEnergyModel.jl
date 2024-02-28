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
# Add another line to rep-periods-data.csv and rep-periods-mapping.csv
open(joinpath(input_dir, "rep-periods-data.csv"), "a") do io
    println(io, "3,$new_rp_length,0.1")
end
open(joinpath(input_dir, "rep-periods-mapping.csv"), "a") do io
    println(io, "216,3,1")
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

@time graph, representative_periods, base_periods =
    create_graph_and_representative_periods_from_csv_folder(input_dir);
@benchmark create_graph_and_representative_periods_from_csv_folder($input_dir)
# @profview create_graph_and_representative_periods_from_csv_folder(input_dir);

#%%

@time constraints_partitions = compute_constraints_partitions(graph, representative_periods);
@benchmark compute_constraints_partitions($graph, $representative_periods)
# @profview compute_constraints_partitions(graph, representative_periods);

#%%

@time dataframes =
    construct_dataframes(graph, representative_periods, constraints_partitions, base_periods)
@benchmark construct_dataframes(
    $graph,
    $representative_periods,
    $constraints_partitions,
    $base_periods,
)
# @profview construct_dataframes($graph, $representative_periods, $constraints_partitions, $base_periods)

#%%

@time model = create_model(graph, representative_periods, dataframes, base_periods);
@benchmark create_model($graph, $representative_periods, $dataframes, $base_periods)
# @profview create_model(graph, representative_periods, dataframes, base_periods);
