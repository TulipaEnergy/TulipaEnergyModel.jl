export GraphAssetData, GraphFlowData, RepresentativePeriod, TimeBlock

const TimeBlock = UnitRange{Int}

"""
Structure to hold the data of one representative period.
"""
struct RepresentativePeriod
    weight::Float64
    time_steps::TimeBlock
    resolution::Float64

    function RepresentativePeriod(weight, num_time_steps, resolution)
        return new(weight, 1:num_time_steps, resolution)
    end
end

"""
Structure to hold the asset data in the graph.
"""
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
    profiles::Dict{Int,Vector{Float64}}
    partitions::Dict{Int,Vector{TimeBlock}}

    # You don't need profiles to create the struct, so initiate it empty
    function GraphAssetData(
        type,
        investable,
        investment_cost,
        capacity,
        initial_capacity,
        peak_demand,
        initial_storage_capacity,
        initial_storage_level,
        energy_to_power_ratio,
    )
        profiles = Dict{Int,Vector{Float64}}()
        partitions = Dict{Int,Vector{TimeBlock}}()
        return new(
            type,
            investable,
            investment_cost,
            capacity,
            initial_capacity,
            peak_demand,
            initial_storage_capacity,
            initial_storage_level,
            energy_to_power_ratio,
            profiles,
            partitions,
        )
    end
end

"""
Structure to hold the flow data in the graph.
"""
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
    profiles::Dict{Int,Vector{Float64}}
    partitions::Dict{Int,Vector{TimeBlock}}
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
        Dict{Int,Vector{Float64}}(),
        Dict{Int,Vector{TimeBlock}}(),
    )
end

"""
Structure to hold all parts of an energy problem.
"""
mutable struct EnergyProblem
    graph::MetaGraph{
        Int,
        SimpleDiGraph{Int},
        String,
        GraphAssetData,
        GraphFlowData,
        Nothing, # Internal data
        Nothing, # Edge weight function
        Nothing, # Default edge weight
    }
    representative_periods::Vector{RepresentativePeriod}
    # solver_parameters # Part of #246
    # solved::Bool # Only makes sense after #268
end
