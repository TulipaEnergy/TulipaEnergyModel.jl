export GraphAssetData, GraphFlowData, RepresentativePeriod, TimeBlock

const TimeBlock = UnitRange{Int}

"""
Structure to hold the data of one representative period.
"""
struct RepresentativePeriod
    base_periods::Union{Nothing,Dict{Int,Float64}}  # which periods in the full problem formulation does this RP stand for
    weight::Float64
    time_steps::TimeBlock
    resolution::Float64

    function RepresentativePeriod(base_periods, num_time_steps, resolution)
        weight = sum(values(base_periods))
        return new(base_periods, weight, 1:num_time_steps, resolution)
    end
end

"""
Structure to hold the asset data in the graph.
"""
mutable struct GraphAssetData
    type::String
    investable::Bool
    investment_integer::Bool
    investment_cost::Float64
    investment_limit::Union{Missing,Float64}
    capacity::Float64
    initial_capacity::Float64
    peak_demand::Float64
    initial_storage_capacity::Float64
    initial_storage_level::Union{Missing,Float64}
    energy_to_power_ratio::Float64
    profiles::Dict{Int,Vector{Float64}}
    partitions::Dict{Int,Vector{TimeBlock}}
    # Solution
    investment::Float64
    storage_level::Dict{Tuple{Int,TimeBlock},Float64}

    # You don't need profiles to create the struct, so initiate it empty
    function GraphAssetData(
        type,
        investable,
        investment_integer,
        investment_cost,
        investment_limit,
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
            investment_integer,
            investment_cost,
            investment_limit,
            capacity,
            initial_capacity,
            peak_demand,
            initial_storage_capacity,
            initial_storage_level,
            energy_to_power_ratio,
            profiles,
            partitions,
            -1,
            Dict{Tuple{Int,TimeBlock},Float64}(),
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
    investment_integer::Bool
    variable_cost::Float64
    investment_cost::Float64
    investment_limit::Union{Missing,Float64}
    capacity::Float64
    initial_export_capacity::Float64
    initial_import_capacity::Float64
    efficiency::Float64
    profiles::Dict{Int,Vector{Float64}}
    partitions::Dict{Int,Vector{TimeBlock}}
    # Solution
    flow::Dict{Tuple{Int,TimeBlock},Float64}
    investment::Float64
end

function GraphFlowData(flow_data::FlowData)
    return GraphFlowData(
        flow_data.carrier,
        flow_data.active,
        flow_data.is_transport,
        flow_data.investable,
        flow_data.investment_integer,
        flow_data.variable_cost,
        flow_data.investment_cost,
        flow_data.investment_limit,
        flow_data.capacity,
        flow_data.initial_export_capacity,
        flow_data.initial_import_capacity,
        flow_data.efficiency,
        Dict{Int,Vector{Float64}}(),
        Dict{Int,Vector{TimeBlock}}(),
        Dict{Tuple{Int,TimeBlock},Float64}(),
        -1,
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
    constraints_partitions::Dict{Symbol,Dict{Tuple{String,Int},Vector{TimeBlock}}}
    dataframes::Dict{Symbol,DataFrame}
    model::Union{JuMP.Model,Nothing}
    solved::Bool
    objective_value::Float64
    termination_status::JuMP.TerminationStatusCode
    # solver_parameters # Part of #246

    """
        EnergyProblem(graph, representative_periods)

    Minimal constructor. The `constraints_partitions` are computed from the `representative_periods`,
    and the other fields and nothing or set to default values.
    """
    function EnergyProblem(graph, representative_periods)
        constraints_partitions = compute_constraints_partitions(graph, representative_periods)

        return new(
            graph,
            representative_periods,
            constraints_partitions,
            Dict(),
            nothing,
            false,
            NaN,
            JuMP.OPTIMIZE_NOT_CALLED,
        )
    end
end
