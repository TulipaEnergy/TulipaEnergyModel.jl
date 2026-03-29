# Run only once to prepare data (in Github there will already be correct data, so no need to run this)

using DataFrames
using CSV

input_data_file = "base-input-data/simple-case-2-scenarios/equal"
df_profiles = CSV.read(input_data_file * "/profiles-wide.csv", DataFrame)

df_profiles = filter(row -> row.scenario == 2008, df_profiles) # I keep only 2008 scenario
# now i need 2009 with profiles same as 2008
df_dup = copy(df_profiles)
df_dup.scenario .= 2009
df_profiles_new = vcat(df_profiles, df_dup)

CSV.write(input_data_file * "/profiles-wide.csv", df_profiles_new) # overwrite profiles