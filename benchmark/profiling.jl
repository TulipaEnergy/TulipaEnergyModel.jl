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
# Add another partition to timeframe partitions to match the new size
lines = readlines(joinpath(input_dir, "assets-timeframe-partitions.csv"))
open(joinpath(input_dir, "assets-timeframe-partitions.csv"), "w") do io
    println(io, lines[1])
    println(io, lines[2])
    for line in lines[3:end]
        println(io, "$line+1x1")
    end
end
# Add profiles to flow and asset
open(joinpath(input_dir, "flows-profiles.csv"), "a") do io
    for (u, v) in [("Asgard_E_demand", "Valhalla_E_balance")]
        for i in 1:new_rp_length
            println(io, "$u,$v,3,$i,0.95")
        end
    end
end
open(joinpath(input_dir, "assets-profiles.csv"), "a") do io
    for a in ["Asgard_E_demand"]
        for i in 1:new_rp_length
            println(io, "$a,3,$i,0.95")
        end
    end
end

input_dir = joinpath(@__DIR__, "EU")

#%%

@time table_tree = create_input_dataframes_from_csv_folder(input_dir);
@benchmark create_input_dataframes_from_csv_folder($input_dir)
# @profview create_input_dataframes_from_csv_folder(input_dir)

#%%

@time graph, representative_periods, timeframe = create_internal_structures(table_tree);
@benchmark create_internal_structures($table_tree)
# @profview create_internal_structures(table_tree);

#%%
@time compute_variables_and_constraints_dataframes!(table_tree)
@benchmark compute_variables_and_constraints_dataframes!(table_tree)
@profview compute_variables_and_constraints_dataframes!(table_tree)

#%%

@time model = create_model(graph, representative_periods, dataframes, timeframe);
@benchmark create_model($graph, $representative_periods, $dataframes, $timeframe)
# @profview create_model(graph, representative_periods, dataframes, timeframe);

#%%

@profview create_energy_problem_from_csv_folder(joinpath(@__DIR__, "EU"))
