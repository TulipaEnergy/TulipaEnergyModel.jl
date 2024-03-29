export GraphAssetData,
    GraphFlowData, EnergyProblem, RepresentativePeriod, PeriodsBlock, TimestepsBlock, Timeframe

const TimestepsBlock = UnitRange{Int}
const PeriodsBlock = UnitRange{Int}

"""
Structure to hold the data of the timeframe.
"""
struct Timeframe
    num_periods::Int64
    map_periods_to_rp::DataFrame
end

"""
Structure to hold the data of one representative period.
"""
struct RepresentativePeriod
    mapping::Union{Nothing,Dict{Int,Float64}}  # which periods in the full problem formulation does this RP stand for
    weight::Float64
    timesteps::TimestepsBlock
    resolution::Float64

    function RepresentativePeriod(mapping, num_timesteps, resolution)
        weight = sum(values(mapping))
        return new(mapping, weight, 1:num_timesteps, resolution)
    end
end

"""
Structure to hold the asset data in the graph.
"""
mutable struct GraphAssetData
    type::Symbol
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
    timeframe_profiles::Dict{Symbol,Vector{Float64}}
    rep_periods_profiles::Dict{Tuple{Symbol,Int},Vector{Float64}}
    timeframe_partitions::Vector{PeriodsBlock}
    rep_periods_partitions::Dict{Int,Vector{TimestepsBlock}}
    # Solution
    investment::Float64
    storage_level_intra_rp::Dict{Tuple{Int,TimestepsBlock},Float64}
    storage_level_inter_rp::Dict{PeriodsBlock,Float64}

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
        timeframe_profiles = Dict{Symbol,Vector{Float64}}()
        rep_periods_profiles = Dict{Tuple{Symbol,Int},Vector{Float64}}()
        timeframe_partitions = PeriodsBlock[]
        rep_periods_partitions = Dict{Int,Vector{TimestepsBlock}}()
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
            timeframe_profiles,
            rep_periods_profiles,
            timeframe_partitions,
            rep_periods_partitions,
            -1,
            Dict{Tuple{Int,TimestepsBlock},Float64}(),
            Dict{TimestepsBlock,Float64}(),
        )
    end
end

"""
Structure to hold the flow data in the graph.
"""
mutable struct GraphFlowData
    carrier::Symbol
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
    timeframe_profiles::Dict{Symbol,Vector{Float64}}
    rep_periods_profiles::Dict{Tuple{Symbol,Int},Vector{Float64}}
    timeframe_partitions::Vector{PeriodsBlock}
    rep_periods_partitions::Dict{Int,Vector{TimestepsBlock}}
    # Solution
    flow::Dict{Tuple{Int,TimestepsBlock},Float64}
    investment::Float64
end

function GraphFlowData(
    carrier,
    active,
    is_transport,
    investable,
    investment_integer,
    variable_cost,
    investment_cost,
    investment_limit,
    capacity,
    initial_export_capacity,
    initial_import_capacity,
    efficiency,
)
    return GraphFlowData(
        carrier,
        active,
        is_transport,
        investable,
        investment_integer,
        variable_cost,
        investment_cost,
        investment_limit,
        capacity,
        initial_export_capacity,
        initial_import_capacity,
        efficiency,
        Dict{Symbol,Vector{Float64}}(),
        Dict{Tuple{Symbol,Int},Vector{Float64}}(),
        PeriodsBlock[],
        Dict{Int,Vector{TimestepsBlock}}(),
        Dict{Tuple{Int,TimestepsBlock},Float64}(),
        -1,
    )
end

mutable struct Solution
    assets_investment::Dict{Symbol,Float64}
    flows_investment::Dict{Tuple{Symbol,Symbol},Float64}
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
- `timeframe`: The number of periods of the `representative_periods`.
- `dataframes`: The data frames used to linearize the variables and constraints. These are used internally in the model only.
- `model`: A JuMP.Model object representing the optimization model.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem.
- `termination_status`: The termination status of the optimization model.
- `time_read_data`: Time taken for reading the data (in seconds).
- `time_create_model`: Time taken for creating the model (in seconds).
- `time_solve_model`: Time taken for solving the model (in seconds).


# Constructor
- `EnergyProblem(graph, representative_periods, timeframe)`: Constructs a new `EnergyProblem` object with the given graph, representative periods, and timeframe. The `constraints_partitions` field is computed from the `representative_periods`, and the other fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.
"""
mutable struct EnergyProblem
    graph::MetaGraph{
        Int,
        SimpleDiGraph{Int},
        Symbol,
        GraphAssetData,
        GraphFlowData,
        Nothing, # Internal data
        Nothing, # Edge weight function
        Nothing, # Default edge weight
    }
    representative_periods::Vector{RepresentativePeriod}
    constraints_partitions::Dict{Symbol,Dict{Tuple{Symbol,Int},Vector{TimestepsBlock}}}
    timeframe::Timeframe
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
        EnergyProblem(graph, representative_periods, timeframe)

    Constructs a new EnergyProblem object with the given graph, representative periods, and timeframe. The `constraints_partitions` field is computed from the `representative_periods`,
    and the other fields and nothing or set to default values.
    """
    function EnergyProblem(graph, representative_periods, timeframe)
        constraints_partitions = compute_constraints_partitions(graph, representative_periods)

        return new(
            graph,
            representative_periods,
            constraints_partitions,
            timeframe,
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
        println(io, "    - Number of variables: ", JuMP.num_variables(ep.model))
        println(
            io,
            "    - Number of constraints for variable bounds: ",
            JuMP.num_constraints(ep.model; count_variable_in_set_constraints = true) -
            JuMP.num_constraints(ep.model; count_variable_in_set_constraints = false),
        )
        println(
            io,
            "    - Number of structural constraints: ",
            JuMP.num_constraints(ep.model; count_variable_in_set_constraints = false),
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
