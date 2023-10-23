struct AssetData
    id::Int                     # Asset ID
    name::String                # Name of Asset (geographical?)
    type::String                # Producer/Consumer - maybe an enum?
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    capacity::Float64           # MW
    initial_capacity::Float64   # MW
    peak_demand::Float64        # MW
end

struct FlowData
    id::Int                     # Flow ID
    carrier::String             # (Optional?) Energy carrier
    from_asset_id::Int           # Asset ID
    to_asset_id::Int             # Asset ID
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    capacity::Float64           # MW
    initial_capacity::Float64   # MW
end

struct FlowProfiles
    id::Int                     # Flow ID
    rep_period_id::Int
    time_step::Int
    value::Float64              # p.u.
end

struct AssetProfiles
    id::Int                     # Asset ID
    rep_period_id::Int
    time_step::Int
    value::Float64              # p.u.
end

struct RepPeriodData
    id::Int
    weight::Float64
end
