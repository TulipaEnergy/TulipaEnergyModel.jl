struct AssetData
    id::Int                         # Asset ID
    name::String                    # Name of Asset (geographical?)
    type::String                    # Producer/Consumer - maybe an enum?
    active::Bool                    # Active or decomissioned
    investable::Bool                # Whether able to invest
    variable_cost::Float64          # kEUR/MWh
    investment_cost::Float64        # kEUR/MW/year
    capacity::Float64               # MW
    initial_capacity::Float64       # MW
    peak_demand::Float64            # MW
    storage_time::Float64           # Hours
end

struct FlowData
    id::Int                     # Flow ID
    carrier::String             # (Optional?) Energy carrier
    from_asset::String          # Name of Asset
    to_asset::String            # Name of Asset
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    capacity::Float64           # MW
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
end
