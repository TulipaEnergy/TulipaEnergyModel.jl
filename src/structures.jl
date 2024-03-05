export GraphAssetData, GraphFlowData, EnergyProblem, RepresentativePeriod, BasePeriod, TimeBlock

const TimeBlock = UnitRange{Int}

"""
Structure to hold the data of the base periods.
"""
struct BasePeriod
    num_base_periods::Int64
    rp_mapping_df::DataFrame
end

"""
Structure to hold the data of one representative period.
"""
struct RepresentativePeriod
    mapping::Union{Nothing,Dict{Int,Float64}}  # which periods in the full problem formulation does this RP stand for
    weight::Float64
    time_steps::TimeBlock
    resolution::Float64

    function RepresentativePeriod(mapping, num_time_steps, resolution)
        weight = sum(values(mapping))
        return new(mapping, weight, 1:num_time_steps, resolution)
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
    is_seasonal::Bool
    storage_inflows::Union{Missing,Float64}
    initial_storage_capacity::Float64
    initial_storage_level::Union{Missing,Float64}
    energy_to_power_ratio::Float64
    base_periods_profiles::Dict{String,Vector{Float64}}
    rep_periods_profiles::Dict{Tuple{String,Int},Vector{Float64}}
    base_periods_partitions::Vector{TimeBlock}
    rep_periods_partitions::Dict{Int,Vector{TimeBlock}}
    # Solution
    investment::Float64
    storage_level_intra_rp::Dict{Tuple{Int,TimeBlock},Float64}
    storage_level_inter_rp::Dict{TimeBlock,Float64}

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
        is_seasonal,
        storage_inflows,
        initial_storage_capacity,
        initial_storage_level,
        energy_to_power_ratio,
    )
        base_periods_profiles = Dict{String,Vector{Float64}}()
        rep_periods_profiles = Dict{Tuple{String,Int},Vector{Float64}}()
        base_periods_partitions = TimeBlock[]
        rep_periods_partitions = Dict{Int,Vector{TimeBlock}}()
        return new(
            type,
            investable,
            investment_integer,
            investment_cost,
            investment_limit,
            capacity,
            initial_capacity,
            peak_demand,
            is_seasonal,
            storage_inflows,
            initial_storage_capacity,
            initial_storage_level,
            energy_to_power_ratio,
            base_periods_profiles,
            rep_periods_profiles,
            base_periods_partitions,
            rep_periods_partitions,
            -1,
            Dict{Tuple{Int,TimeBlock},Float64}(),
            Dict{TimeBlock,Float64}(),
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
    base_periods_profiles::Dict{String,Vector{Float64}}
    rep_periods_profiles::Dict{Tuple{String,Int},Vector{Float64}}
    base_periods_partitions::Vector{TimeBlock}
    rep_periods_partitions::Dict{Int,Vector{TimeBlock}}
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
        Dict{String,Vector{Float64}}(),
        Dict{Tuple{String,Int},Vector{Float64}}(),
        TimeBlock[],
        Dict{Int,Vector{TimeBlock}}(),
        Dict{Tuple{Int,TimeBlock},Float64}(),
        -1,
    )
end

mutable struct Solution
    assets_investment::Dict{String,Float64}
    flows_investment::Dict{Tuple{String,String},Float64}
    storage_level_intra_rp::Vector{Float64}
    storage_level_inter_rp::Vector{Float64}
    flow::Vector{Float64}
    objective_value::Float64
    duals::Union{Nothing,Dict{Symbol,Vector{Float64}}}
end

"""
Structure to hold all parts of an energy problem. It is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

# Fields
- `graph`: The [Graph](@ref) object that defines the geometry of the energy problem.
- `representative_periods`: A vector of [Representative Periods](@ref representative-periods).
- `constraints_partitions`: Dictionaries that connect pairs of asset and representative periods to [time partitions (vectors of time blocks)](@ref Partition)
- `base_periods`: The number of periods of the `representative_periods`.
- `dataframes`: The data frames used to linearize the variables and constraints. These are used internally in the model only.
- `model`: A JuMP.Model object representing the optimization model.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem.
- `termination_status`: The termination status of the optimization model.
- `time_read_data`: Time taken for reading the data (in seconds).
- `time_create_model`: Time taken for creating the model (in seconds).
- `time_solve_model`: Time taken for solving the model (in seconds).


# Constructor
- `EnergyProblem(graph, representative_periods, base_periods)`: Constructs a new `EnergyProblem` object with the given graph, representative periods, and base periods. The `constraints_partitions` field is computed from the `representative_periods`, and the other fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.
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
    base_periods::BasePeriod
    dataframes::Dict{Symbol,DataFrame}
    model::Union{JuMP.Model,Nothing}
    solution::Union{Solution,Nothing}
    solved::Bool
    objective_value::Float64
    termination_status::JuMP.TerminationStatusCode
    time_read_data::Float64
    time_create_model::Float64
    time_solve_model::Float64

    """
        EnergyProblem(graph, representative_periods, base_periods)

    Constructs a new EnergyProblem object with the given graph, representative periods, and base periods. The `constraints_partitions` field is computed from the `representative_periods`,
    and the other fields and nothing or set to default values.
    """
    function EnergyProblem(graph, representative_periods, base_periods)
        constraints_partitions = compute_constraints_partitions(graph, representative_periods)

        return new(
            graph,
            representative_periods,
            constraints_partitions,
            base_periods,
            Dict(),
            nothing,
            nothing,
            false,
            NaN,
            JuMP.OPTIMIZE_NOT_CALLED,
            NaN,
            NaN,
            NaN,
        )
    end
end

function Base.show(io::IO, ep::EnergyProblem)
    status_model_creation = !isnothing(ep.model)
    status_model_solved = ep.solved

    println(io, "EnergyProblem:")
    println(io, "  - Time for reading the data (in seconds): ", ep.time_read_data)
    if status_model_creation
        println(io, "  - Model created!")
        println(io, "    - Time for creating the model (in seconds): ", ep.time_create_model)
        println(io, "    - Number of variables: ", num_variables(ep.model))
        println(
            io,
            "    - Number of constraints for variable bounds: ",
            num_constraints(ep.model; count_variable_in_set_constraints = true) -
            num_constraints(ep.model; count_variable_in_set_constraints = false),
        )
        println(
            io,
            "    - Number of structual constraints: ",
            num_constraints(ep.model; count_variable_in_set_constraints = false),
        )
    else
        println(io, "  - Model not created!")
    end
    if status_model_solved
        println(io, "  - Model solved! ")
        println(io, "    - Time for solving the model (in seconds): ", ep.time_solve_model)
        println(io, "    - Termination status: ", ep.termination_status)
        println(io, "    - Objective value: ", ep.objective_value)
    elseif !status_model_solved && ep.termination_status == JuMP.INFEASIBLE
        println(io, "  - Model is infeasible!")
    else
        println(io, "  - Model not solved!")
    end
end
