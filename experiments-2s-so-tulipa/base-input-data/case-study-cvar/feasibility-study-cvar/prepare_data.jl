# Run only once to prepare data (in Github there will already be correct data, so no need to run this)

using DataFrames
using CSV

input_data_file = "C:/Users/fjlaseur/Tulipa/CVaR/TulipaEnergyModel.jl/experiments-2s-so-tulipa/base-input-data/case-study-cvar/feasibility-study-cvar"
df_profiles = CSV.read(input_data_file * "/profiles-wide.csv", DataFrame)

scenario_plan = Dict{
    Int,
    NamedTuple{
        (:source, :solar_factor, :wind_onshore_factor, :wind_offshore_factor),
        Tuple{Int,Float64,Float64,Float64},
    },
}()

# source encoding:
# 1 => solar
# 2 => wind_offshore
# 3 => wind_onshore
#
# solar_factor:
#   +1.0 => HA
#   -1.0 => LA
#
# wind_onshore_factor:
#   +1.0 => HD
#   -1.0 => LD
#
# wind_offshore_factor is unused here, kept only to respect the requested format

labels = collect(1995:2006)

k = 1
for src in 1:3
    scenario_plan[labels[k]] = (src, +1.0, -1.0, 0.0)
    k += 1   # LD_HA
    scenario_plan[labels[k]] = (src, -1.0, -1.0, 0.0)
    k += 1   # LD_LA
    scenario_plan[labels[k]] = (src, +1.0, +1.0, 0.0)
    k += 1   # HD_HA
    scenario_plan[labels[k]] = (src, -1.0, +1.0, 0.0)
    k += 1   # HD_LA
end

sources = Dict(1 => :solar, 2 => :wind_offshore, 3 => :wind_onshore)

function pick_row_index(g::SubDataFrame, col::Symbol, mode::Symbol)
    vals = g[!, col]
    if mode == :min
        return argmin(vals)
    elseif mode == :max
        return argmax(vals)
    else
        error("Unsupported mode: $mode")
    end
end

df_list = DataFrame[]

gdf = groupby(df_profiles, :timestep)

for g in gdf
    i_ld = pick_row_index(g, :demand, :min)
    i_hd = pick_row_index(g, :demand, :max)

    row_ld = g[i_ld, :]
    row_hd = g[i_hd, :]

    for label in sort(collect(keys(scenario_plan)))
        spec = scenario_plan[label]
        src_col = sources[spec.source]

        demand_row = spec.wind_onshore_factor == -1.0 ? row_ld : row_hd
        availability_mode = spec.solar_factor == +1.0 ? :max : :min
        availability_value = g[pick_row_index(g, src_col, availability_mode), src_col]

        new_row = DataFrame(demand_row)
        new_row.scenario .= label
        new_row[!, src_col] .= availability_value

        push!(df_list, new_row)
    end
end

df_profiles_new = vcat(df_list...)

# Optional: sort rows nicely
sort!(df_profiles_new, [:scenario, :timestep])

# Overwrite profiles-wide.csv
CSV.write(input_data_file * "/profiles-wide.csv", df_profiles_new)
