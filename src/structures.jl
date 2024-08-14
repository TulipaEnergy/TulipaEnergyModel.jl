export GraphAssetData,
    GraphFlowData, EnergyProblem, RepresentativePeriod, PeriodsBlock, TimestepsBlock, Timeframe

const TimestepsBlock = UnitRange{Int}
const PeriodsBlock = UnitRange{Int}

const PeriodType = Symbol
const PERIOD_TYPES = [:rep_periods, :timeframe]

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
    weight::Float64
    timesteps::TimestepsBlock
    resolution::Float64

    function RepresentativePeriod(weight, num_timesteps, resolution)
        return new(weight, 1:num_timesteps, resolution)
    end
end

"""
Structure to hold the asset data in the graph.
"""
mutable struct GraphAssetData
    type::String
    active::Dict{Int,Bool}
    investable::Dict{Int,Bool}
    investment_integer::Dict{Int,Bool}
    investment_cost::Dict{Int,Float64}
    investment_limit::Dict{Int,Union{Missing,Float64}}
    capacity::Dict{Int,Float64}
    initial_capacity::Dict{Int,Float64}
    peak_demand::Dict{Int,Float64}
    consumer_balance_sense::Dict{Int,Union{MathOptInterface.EqualTo,MathOptInterface.GreaterThan}}
    is_seasonal::Dict{Int,Bool}
    storage_inflows::Dict{Int,Union{Missing,Float64}}
    initial_storage_capacity::Dict{Int,Float64}
    initial_storage_level::Dict{Int,Union{Missing,Float64}}
    energy_to_power_ratio::Dict{Int,Float64}
    storage_method_energy::Dict{Int,Bool}
    investment_cost_storage_energy::Dict{Int,Float64}
    investment_limit_storage_energy::Dict{Int,Union{Missing,Float64}}
    capacity_storage_energy::Dict{Int,Float64}
    investment_integer_storage_energy::Dict{Int,Bool}
    use_binary_storage_method::Dict{Int,Union{Missing,String}}
    max_energy_timeframe_partition::Dict{Int,Union{Missing,Float64}}
    min_energy_timeframe_partition::Dict{Int,Union{Missing,Float64}}
    timeframe_profiles::Dict{Int,Dict{String,Vector{Float64}}}
    rep_periods_profiles::Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}
    timeframe_partitions::Dict{Int,Vector{PeriodsBlock}}
    rep_periods_partitions::Dict{Int,Dict{Int,Vector{TimestepsBlock}}}
    # rep_periods_partitions::Dict{Int,Vector{TimestepsBlock}}
    # Solution
    investment::Float64
    investment_energy::Float64 # for storage assets with energy method
    storage_level_intra_rp::Dict{Tuple{Int,TimestepsBlock},Float64}
    storage_level_inter_rp::Dict{PeriodsBlock,Float64}
    max_energy_inter_rp::Dict{PeriodsBlock,Float64}
    min_energy_inter_rp::Dict{PeriodsBlock,Float64}

    # You don't need profiles to create the struct, so initiate it empty
    function GraphAssetData(
        type,
        active,
        investable,
        investment_integer,
        investment_cost,
        investment_limit,
        capacity,
        initial_capacity,
        peak_demand,
        consumer_balance_sense,
        is_seasonal,
        storage_inflows,
        initial_storage_capacity,
        initial_storage_level,
        energy_to_power_ratio,
        storage_method_energy,
        investment_cost_storage_energy,
        investment_limit_storage_energy,
        capacity_storage_energy,
        investment_integer_storage_energy,
        use_binary_storage_method,
        max_energy_timeframe_partition,
        min_energy_timeframe_partition,
    )
        timeframe_profiles = Dict{Int,Dict{String,Vector{Float64}}}()
        rep_periods_profiles = Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}()
        timeframe_partitions = Dict{Int,PeriodsBlock}()
        rep_periods_partitions = Dict{Int,Dict{Int,Vector{TimestepsBlock}}}()
        return new(
            type,
            active,
            investable,
            investment_integer,
            investment_cost,
            investment_limit,
            capacity,
            initial_capacity,
            peak_demand,
            consumer_balance_sense,
            is_seasonal,
            storage_inflows,
            initial_storage_capacity,
            initial_storage_level,
            energy_to_power_ratio,
            storage_method_energy,
            investment_cost_storage_energy,
            investment_limit_storage_energy,
            capacity_storage_energy,
            investment_integer_storage_energy,
            use_binary_storage_method,
            max_energy_timeframe_partition,
            min_energy_timeframe_partition,
            timeframe_profiles,
            rep_periods_profiles,
            timeframe_partitions,
            rep_periods_partitions,
            -1,
            -1,
            Dict{Tuple{Int,TimestepsBlock},Float64}(),
            Dict{TimestepsBlock,Float64}(),
            Dict{TimestepsBlock,Float64}(),
            Dict{TimestepsBlock,Float64}(),
        )
    end
end

"""
Structure to hold the flow data in the graph.
"""
mutable struct GraphFlowData
    carrier::String
    active::Dict{Int,Bool}
    is_transport::Dict{Int,Bool}
    investable::Dict{Int,Bool}
    investment_integer::Dict{Int,Bool}
    variable_cost::Dict{Int,Float64}
    investment_cost::Dict{Int,Float64}
    investment_limit::Dict{Int,Union{Missing,Float64}}
    capacity::Dict{Int,Float64}
    initial_export_capacity::Dict{Int,Float64}
    initial_import_capacity::Dict{Int,Float64}
    efficiency::Dict{Int,Float64}
    timeframe_profiles::Dict{Int,Dict{String,Vector{Float64}}}
    rep_periods_profiles::Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}
    timeframe_partitions::Dict{Int,Vector{PeriodsBlock}}
    rep_periods_partitions::Dict{Int,Dict{Int,Vector{TimestepsBlock}}}
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
        Dict{Int,Dict{String,Vector{Float64}}}(),
        Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}(),
        Dict{Int,Vector{PeriodsBlock}}(),
        Dict{Int,Dict{Int,Vector{TimestepsBlock}}}(),
        Dict{Int,Dict{Int,Vector{TimestepsBlock}}}(),
        -1,
    )
end

mutable struct Solution
    assets_investment::Dict{String,Float64}
    assets_investment_energy::Dict{String,Float64} # for storage assets with energy method
    flows_investment::Dict{Tuple{String,String},Float64}
    storage_level_intra_rp::Vector{Float64}
    storage_level_inter_rp::Vector{Float64}
    max_energy_inter_rp::Vector{Float64}
    min_energy_inter_rp::Vector{Float64}
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
- `timings`: Dictionary of elapsed time for various parts of the code (in seconds).

# Constructor
- `EnergyProblem(connection)`: Constructs a new `EnergyProblem` object with the given connection. The `constraints_partitions` field is computed from the `representative_periods`, and the other fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.
"""
mutable struct EnergyProblem
    db_connection::DuckDB.DB
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
    representative_periods::Dict{Int,Vector{RepresentativePeriod}}
    constraints_partitions::Dict{Symbol,Dict{Tuple{String,Int,Int},Vector{TimestepsBlock}}}
    timeframe::Timeframe
    dataframes::Dict{Symbol,DataFrame}
    model::Union{JuMP.Model,Nothing}
    solution::Union{Solution,Nothing}
    solved::Bool
    objective_value::Float64
    termination_status::JuMP.TerminationStatusCode
    timings::Dict{String,Float64}

    """
        EnergyProblem(connection)

    Constructs a new EnergyProblem object using the `connection`.
    This will call relevant functions to generate all input that is required for the model creation.
    """
    function EnergyProblem(connection)
        elapsed_time_internal = @elapsed begin
            graph, representative_periods, timeframe = create_internal_structures(connection)
        end
        elapsed_time_cons = @elapsed begin
            constraints_partitions = compute_constraints_partitions(graph, representative_periods)
        end

        energy_problem = new(
            connection,
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
            Dict(
                "creating internal structures" => elapsed_time_internal,
                "computing constraints partitions" => elapsed_time_cons,
            ),
        )

        return energy_problem
    end
end

function Base.show(io::IO, ep::EnergyProblem)
    status_model_creation = !isnothing(ep.model)
    status_model_solved = ep.solved

    timing_str(prefix, field) = begin
        t = get(ep.timings, field, "-")
        "$prefix $field (in seconds): $t"
    end

    println(io, "EnergyProblem:")
    println(io, "  - ", timing_str("Time", "creating internal structures"))
    println(io, "  - ", timing_str("Time", "computing constraints partitions"))
    if status_model_creation
        println(io, "  - Model created!")
        println(io, "    - ", timing_str("Time for ", "creating the model"))
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
        println(io, "    - ", timing_str("Time for ", "solving the model"))
        println(io, "    - Termination status: ", ep.termination_status)
        println(io, "    - Objective value: ", ep.objective_value)
    elseif !status_model_solved && ep.termination_status == JuMP.INFEASIBLE
        println(io, "  - Model is infeasible!")
    else
        println(io, "  - Model not solved!")
    end
end
