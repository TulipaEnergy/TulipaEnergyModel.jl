struct NodeData
    id::Int                     # Node ID
    name::String                # Name of node (geographical?)
    type::String                # Producer/Consumer - maybe an enum?
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float32      # kEUR/MWh
    investment_cost::Float32    # kEUR/MW/year
    capacity::Float32           # MW
    initial_capacity::Float32   # MW
    peak_demand::Float32        # MW
end

struct EdgeData
    id::Int                     # Edge ID
    carrier::String             # (Optional?) Energy carrier
    from_node_id::Int           # Node ID
    to_node_id::Int             # Node ID
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float32      # kEUR/MWh
    investment_cost::Float32    # kEUR/MW/year
    capacity::Float32           # MW
    initial_capacity::Float32   # MW
end

struct EdgeProfiles
    id::Int                     # Edge ID
    rep_period_id::Int
    time_step::Int
    value::Float32              # p.u.
end

struct NodeProfiles
    id::Int                     # Node ID
    rep_period_id::Int
    time_step::Int
    value::Float32              # p.u.
end

struct RepPeriodData
    id::Int
    weight::Float32
end
