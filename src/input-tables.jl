struct AssetData
    id::Int                           # Asset ID
    name::String                      # Name of Asset (geographical?)
    type::String                      # Producer/Consumer - maybe an enum?
    active::Bool                      # Active or decomissioned
    investable::Bool                  # Whether able to invest
    investment_cost::Float64          # kEUR/MW/year
    capacity::Float64                 # MW
    initial_capacity::Float64         # MW
    peak_demand::Float64              # MW
    initial_storage_capacity::Float64 # MWh
    energy_to_power_ratio::Float64    # Hours
end

struct FlowData
    id::Int                     # Flow ID
    carrier::String             # (Optional?) Energy carrier
    from_asset::String          # Name of Asset
    to_asset::String            # Name of Asset
    active::Bool                # Active or decomissioned
    is_transport::Bool          # Whether a transport flow
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    export_capacity::Float64    # MW
    import_capacity::Float64    # MW
    initial_capacity::Float64   # MW
    efficiency::Float64         # p.u. (per unit)
end

struct FlowProfiles
    id::Int                     # Flow ID
    rep_period_id::Int          # Representative period ID
    time_step::Int              # Time step ID
    value::Float64              # p.u. (per unit)
end

struct AssetProfiles
    id::Int                     # Asset ID
    rep_period_id::Int          # Representative period ID
    time_step::Int              # Time step ID
    value::Float64              # p.u. (per unit)
end

struct RepPeriodData
    id::Int                     # Representative period ID
    weight::Float64             # Hours
    num_time_steps::Int         # Numer of time steps
    resolution::Float64         # Duration of each time steps (hours)
end

struct PartitionData
    id::Int
    rep_period_id::Int
    specification::Symbol
    partition::String
end
