export GraphFlowData

mutable struct GraphAssetData
    type::String
    investable::Bool
    investment_cost::Float64
    capacity::Float64
    initial_capacity::Float64
    peak_demand::Float64
    initial_storage_capacity::Float64
    initial_storage_level::Float64
    energy_to_power_ratio::Float64
end

mutable struct GraphFlowData
    carrier::String
    active::Bool
    is_transport::Bool
    investable::Bool
    variable_cost::Float64
    investment_cost::Float64
    import_capacity::Float64
    export_capacity::Float64
    unit_capacity::Float64
    initial_capacity::Float64
    efficiency::Float64
end

function GraphFlowData(flow_data::FlowData)
    return GraphFlowData(
        flow_data.carrier,
        flow_data.active,
        flow_data.is_transport,
        flow_data.investable,
        flow_data.variable_cost,
        flow_data.investment_cost,
        flow_data.import_capacity,
        flow_data.export_capacity,
        max(flow_data.export_capacity, flow_data.import_capacity),
        flow_data.initial_capacity,
        flow_data.efficiency,
    )
end
