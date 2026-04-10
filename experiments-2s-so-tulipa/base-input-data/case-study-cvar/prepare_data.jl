using DataFrames
using CSV

input_data_file = "C:/Users/fjlaseur/Tulipa/CVaR/TulipaEnergyModel.jl/experiments-2s-so-tulipa/base-input-data/case-study-cvar/"
df_profiles = CSV.read(input_data_file * "/profiles-wide.csv", DataFrame)

# ------------------------------------------------------------------------------
# 1) Keep only the 3 original scenarios that already exist in the file
# ------------------------------------------------------------------------------
base_scenarios = [1995, 2008, 2009]
df_profiles = filter(row -> row.scenario in base_scenarios, df_profiles)

# ------------------------------------------------------------------------------
# 2) Choose the target labels

target_scenarios = collect(1995:2024)

# ------------------------------------------------------------------------------
# 3) Define, for each target scenario label:
#    - which existing scenario to copy from
#    - which multiplicative factors to apply
#
# Keep 1995, 2008, 2009 unchanged.

scenario_plan = Dict{
    Int,
    NamedTuple{
        (:source, :solar_factor, :wind_onshore_factor, :wind_offshore_factor),
        Tuple{Int,Float64,Float64,Float64},
    },
}()

for s in target_scenarios
    if s == 1995 || s == 2008 || s == 2009
        scenario_plan[s] =
            (source = s, solar_factor = 1.0, wind_onshore_factor = 1.0, wind_offshore_factor = 1.0)
    else
        source = [1995, 2008, 2009][mod1(s - first(target_scenarios), 3)]

        solar_factor         = [0.80, 0.90, 1.00, 1.10, 1.20][mod1(s - first(target_scenarios), 5)]
        wind_onshore_factor  = [0.85, 0.95, 1.00, 1.05, 1.15][mod1(s - first(target_scenarios) + 1, 5)]
        wind_offshore_factor = [0.75, 0.90, 1.00, 1.10, 1.25][mod1(s - first(target_scenarios) + 2, 5)]

        scenario_plan[s] = (
            source = source,
            solar_factor = solar_factor,
            wind_onshore_factor = wind_onshore_factor,
            wind_offshore_factor = wind_offshore_factor,
        )
    end
end

#Build the new dataframe with all target scenarios

dfs_new = DataFrame[]

for s in target_scenarios
    plan = scenario_plan[s]

    df_s = copy(filter(row -> row.scenario == plan.source, df_profiles))
    df_s.scenario .= s

    # Apply factors only if this is an artificial scenario
    if !(s in base_scenarios)
        df_s.solar .*= plan.solar_factor
        df_s.wind_onshore .*= plan.wind_onshore_factor
        df_s.wind_offshore .*= plan.wind_offshore_factor
    end

    push!(dfs_new, df_s)
end

df_profiles_new = vcat(dfs_new...)

# Optional: sort rows nicely
sort!(df_profiles_new, [:scenario, :timestep])

# Overwrite profiles-wide.csv
CSV.write(input_data_file * "/profiles-wide.csv", df_profiles_new)

n_scenarios = length(unique(df_profiles_new.scenario))

df_stochastic_scenario = DataFrame(;
    scenario = sort(unique(df_profiles_new.scenario)),
    probability = fill(1.0 / n_scenarios, n_scenarios),
)
df_probabilities = DataFrame[]

CSV.write(input_data_file * "/stochastic-scenario.csv")
