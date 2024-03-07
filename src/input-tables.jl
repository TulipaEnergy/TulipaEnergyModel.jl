"""
Schema for the assets-data.csv file.
"""
struct AssetData
    name::String                                       # Name of Asset (geographical?)
    type::String                                       # Producer/Consumer/Storage/Conversion
    active::Bool                                       # Active or decomissioned
    investable::Bool                                   # Whether able to invest
    investment_integer::Bool                           # Whether investment is integer or continuous
    investment_cost::Float64                           # kEUR/MW/year
    investment_limit::Union{Missing,Float64}           # MW (Missing -> no limit)
    capacity::Float64                                  # MW
    initial_capacity::Float64                          # MW
    peak_demand::Float64                               # MW
    is_seasonal::Bool                                  # Whether seasonal storage (e.g. hydro) or not (e.g. battery)
    storage_inflows::Float64                           # MWh/year
    initial_storage_capacity::Float64                  # MWh
    initial_storage_level::Union{Missing,Float64}      # MWh (Missing -> free initial level)
    energy_to_power_ratio::Float64                     # Hours
end

"""
Schema for the assets-profiles.csv file.
"""
struct AssetProfiles
    asset::String               # Asset ID
    profile_type::String        # Type of profile, used to determine dataframe with source profile
    profile_name::String        # Name of profile, used to determine data inside the dataframe
end

"""
Schema for the assets-rep-periods-partitions.csv file.
"""
struct AssetRepPeriodPartitionData
    asset::String
    rep_period::Int
    specification::Symbol
    partition::String
end

"""
Schema for the assets-base-periods-partitions.csv file.
"""
struct AssetBasePeriodPartitionData
    asset::String
    specification::Symbol
    partition::String
end

"""
Schema for the flows-data.csv file.
"""
struct FlowData
    carrier::String                             # (Optional?) Energy carrier
    from_asset::String                          # Name of Asset
    to_asset::String                            # Name of Asset
    active::Bool                                # Active or decomissioned
    is_transport::Bool                          # Whether a transport flow
    investable::Bool                            # Whether able to invest
    investment_integer::Bool                    # Whether investment is integer or continuous
    variable_cost::Float64                      # kEUR/MWh
    investment_cost::Float64                    # kEUR/MW/year
    investment_limit::Union{Missing,Float64}    # MW
    capacity::Float64                           # MW
    initial_export_capacity::Float64            # MW
    initial_import_capacity::Float64            # MW
    efficiency::Float64                         # p.u. (per unit)
end

"""
Schema for the flows-profiles file.
"""
struct FlowProfiles
    from_asset::String          # Name of Asset
    to_asset::String            # Name of Asset
    profile_type::String        # Type of profile, used to determine dataframe with source profile
    profile_name::String        # Name of profile, used to determine data inside the dataframe
end

"""
Schema for the flows-rep-periods-partitions.csv file.
"""
struct FlowRepPeriodPartitionData
    from_asset::String          # Name of Asset
    to_asset::String            # Name of Asset
    rep_period::Int
    specification::Symbol
    partition::String
end

"""
Schema for the flows-base-periods-partitions.csv file.
"""
struct FlowBasePeriodPartitionData
    from_asset::String          # Name of Asset
    to_asset::String            # Name of Asset
    specification::Symbol
    partition::String
end

"""
Schema for the rep-period-data.csv file.
"""
struct RepPeriodData
    id::Int                     # Representative period ID
    num_time_steps::Int         # Numer of time steps
    resolution::Float64         # Duration of each time steps (hours)
end

"""
Schema for the rep-periods-mapping.csv file.
"""
struct RepPeriodMapping
    period::Int                 # Period ID
    rep_period::Int             # Representative period ID
    weight::Float64             # Hours
end

"""
Schema for the profiles-base-periods-<type>.csv file.
"""
struct BasePeriodsProfilesData
    profile_name::String        # Asset ID
    base_period::Int            # Base period ID
    value::Float64              # p.u. (per unit)
end

"""
Schema for the profiles-rep-period-<type>.csv file.
"""
struct RepPeriodsProfilesData
    profile_name::String        # Asset ID
    rep_period::Int             # Representative period ID
    time_step::Int              # Time step ID
    value::Float64              # p.u. (per unit)
end
