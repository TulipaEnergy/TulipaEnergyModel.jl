export GraphAssetData,
    GraphFlowData,
    EnergyProblem,
    TulipaVariable,
    TulipaConstraint,
    RepresentativePeriod,
    PeriodsBlock,
    TimestepsBlock,
    Timeframe,
    Group,
    Year

const TimestepsBlock = UnitRange{Int}
const PeriodsBlock = UnitRange{Int}

const PeriodType = Symbol
const PERIOD_TYPES = [:rep_periods, :timeframe]

"""
Structure to hold the data of the year.
"""
struct Year
    id::Int
    length::Int
    is_milestone::Bool
end

"""
Structure to hold the data of the timeframe.
"""
struct Timeframe
    num_periods::Int64
    map_periods_to_rp::DataFrame
end

"""
Structure to hold the JuMP variables for the TulipaEnergyModel
"""
mutable struct TulipaVariable
    indices::DataFrame
    table_name::String
    container::Vector{JuMP.VariableRef}
    lookup::OrderedDict # TODO: This is probably not type stable so it's only used for strangling

    function TulipaVariable(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name") |> DataFrame,
            table_name,
            JuMP.VariableRef[],
            Dict(),
        )
    end
end

mutable struct TulipaConstraint
    indices::DataFrame
    table_name::String
    num_rows::Int
    constraint_names::Vector{Symbol}
    expressions::Dict{Symbol,Vector{JuMP.AffExpr}}
    duals::Dict{Symbol,Vector{Float64}}

    function TulipaConstraint(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name") |> DataFrame,
            table_name,
            only([ # only makes sure that a single value is returned
                row.num_rows for
                row in DuckDB.query(connection, "SELECT COUNT(*) AS num_rows FROM $table_name")
            ]), # This loop is required to access the query resulted, because it's a lazy struct
            Symbol[],
            Dict(),
            Dict(),
        )
    end
end

"""
    attach_constraint!(model, cons, name, container)

Attach a constraint named `name` stored in `container`, and set `model[name] = container`.
This checks that the `container` length matches the stored `indices` number of rows.
"""
function attach_constraint!(
    model::JuMP.Model,
    cons::TulipaConstraint,
    name::Symbol,
    container::Vector{<:JuMP.ConstraintRef},
)
    @assert length(container) == cons.num_rows
    push!(cons.constraint_names, name)
    model[name] = container
    return nothing
end

function attach_constraint!(model::JuMP.Model, cons::TulipaConstraint, name::Symbol, container)
    # This should be the empty case container = Any[]
    @assert length(container) == 0
    @assert cons.num_rows == 0
    empty_container = JuMP.ConstraintRef{JuMP.Model,Missing,JuMP.ScalarShape}[]
    model[name] = empty_container
    return nothing
end

"""
    attach_expression!(cons, name, container)
    attach_expression!(model, cons, name, container)

Attach a expression named `name` stored in `container`, and optionally set `model[name] = container`.
This checks that the `container` length matches the stored `indices` number of rows.
"""
function attach_expression!(cons::TulipaConstraint, name::Symbol, container::Vector{JuMP.AffExpr})
    @assert length(container) = cons.num_rows
    cons.expressions[name] = container
    return nothing
end

function attach_expression!(
    cons::TulipaConstraint,
    name::Symbol,
    container::Vector{JuMP.AffExpr},
    model::JuMP.Model,
)
    attach_expression!(cons, name, container)
    model[name] = container
    return nothing
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
    # asset
    type::String
    group::Union{Missing,String}
    capacity::Float64
    min_operating_point::Union{Missing,Float64}
    investment_method::String
    investment_integer::Bool
    technical_lifetime::Float64
    economic_lifetime::Float64
    discount_rate::Float64
    consumer_balance_sense::Union{MathOptInterface.EqualTo,MathOptInterface.GreaterThan}
    capacity_storage_energy::Float64
    is_seasonal::Bool
    use_binary_storage_method::Union{Missing,String}
    unit_commitment::Bool
    unit_commitment_method::Union{Missing,String}
    unit_commitment_integer::Bool
    ramping::Bool
    storage_method_energy::Bool
    energy_to_power_ratio::Float64
    investment_integer_storage_energy::Bool
    max_ramp_up::Union{Missing,Float64}
    max_ramp_down::Union{Missing,Float64}

    # asset_milestone
    investable::Dict{Int,Bool}
    peak_demand::Dict{Int,Float64}
    storage_inflows::Dict{Int,Union{Missing,Float64}}
    initial_storage_level::Dict{Int,Union{Missing,Float64}}
    min_energy_timeframe_partition::Dict{Int,Union{Missing,Float64}}
    max_energy_timeframe_partition::Dict{Int,Union{Missing,Float64}}
    units_on_cost::Dict{Int,Union{Missing,Float64}}

    # asset_commission
    fixed_cost::Dict{Int,Float64}
    investment_cost::Dict{Int,Float64}
    investment_limit::Dict{Int,Union{Missing,Float64}}
    fixed_cost_storage_energy::Dict{Int,Float64}
    investment_cost_storage_energy::Dict{Int,Float64}
    investment_limit_storage_energy::Dict{Int,Union{Missing,Float64}}

    # asset_both
    active::Dict{Int,Dict{Int,Bool}}
    decommissionable::Dict{Int,Dict{Int,Bool}}
    initial_units::Dict{Int,Dict{Int,Float64}}
    initial_storage_units::Dict{Int,Dict{Int,Float64}}

    # profiles
    timeframe_profiles::Dict{Int,Dict{Int,Dict{String,Vector{Float64}}}}
    rep_periods_profiles::Dict{Int,Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}}

    # Solution
    investment::Dict{Int,Float64}
    investment_energy::Dict{Int,Float64} # for storage assets with energy method
    storage_level_intra_rp::Dict{Tuple{Int,TimestepsBlock},Float64}
    storage_level_inter_rp::Dict{PeriodsBlock,Float64}
    max_energy_inter_rp::Dict{PeriodsBlock,Float64}
    min_energy_inter_rp::Dict{PeriodsBlock,Float64}

    # You don't need profiles to create the struct, so initiate it empty
    function GraphAssetData(args...)
        timeframe_profiles = Dict{Int,Dict{Int,Dict{String,Vector{Float64}}}}()
        rep_periods_profiles = Dict{Int,Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}}()
        return new(
            args...,
            timeframe_profiles,
            rep_periods_profiles,
            Dict{Int,Float64}(),
            Dict{Int,Float64}(),
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
    # flow
    carrier::String
    is_transport::Bool
    capacity::Float64
    technical_lifetime::Float64
    economic_lifetime::Float64
    discount_rate::Float64
    investment_integer::Bool

    # flow_milestone
    investable::Dict{Int,Bool}
    variable_cost::Dict{Int,Float64}

    # flow_commission
    fixed_cost::Dict{Int,Float64}
    investment_cost::Dict{Int,Float64}
    efficiency::Dict{Int,Float64}
    investment_limit::Dict{Int,Union{Missing,Float64}}

    # flow_both
    active::Dict{Int,Dict{Int,Bool}}
    decommissionable::Dict{Int,Dict{Int,Bool}}
    initial_export_units::Dict{Int,Dict{Int,Float64}}
    initial_import_units::Dict{Int,Dict{Int,Float64}}

    # profiles
    timeframe_profiles::Dict{Int,Dict{String,Vector{Float64}}}
    rep_periods_profiles::Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}

    # Solution
    flow::Dict{Tuple{Int,TimestepsBlock},Float64}
    investment::Dict{Int,Float64}
end

function GraphFlowData(args...)
    return GraphFlowData(
        args...,
        Dict{Int,Dict{String,Vector{Float64}}}(),
        Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}(),
        Dict{Int,Dict{Int,Vector{TimestepsBlock}}}(),
        Dict{Int,Float64}(),
    )
end

"""
Structure to hold the group data
"""
struct Group
    name::String
    year::Int
    invest_method::Bool
    min_investment_limit::Union{Missing,Float64}
    max_investment_limit::Union{Missing,Float64}

    function Group(name, year, invest_method, min_investment_limit, max_investment_limit)
        return new(name, year, invest_method, min_investment_limit, max_investment_limit)
    end
end

mutable struct Solution
    assets_investment::Dict{Tuple{Int,String},Float64}
    assets_investment_energy::Dict{Tuple{Int,String},Float64} # for storage assets with energy method
    flows_investment::Any # TODO: Fix this type
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
- `groups`: The input data of the groups to create constraints that are common to a set of assets in the model.
- `model_parameters`: The model parameters.
- `model`: A JuMP.Model object representing the optimization model.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem.
- `termination_status`: The termination status of the optimization model.

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
    variables::Dict{Symbol,TulipaVariable}
    constraints::Dict{Symbol,TulipaConstraint}
    representative_periods::Dict{Int,Vector{RepresentativePeriod}}
    timeframe::Timeframe
    groups::Vector{Group}
    years::Vector{Year}
    model_parameters::ModelParameters
    model::Union{JuMP.Model,Nothing}
    solution::Union{Solution,Nothing}
    solved::Bool
    objective_value::Float64
    termination_status::JuMP.TerminationStatusCode

    """
        EnergyProblem(connection; model_parameters_file = "")

    Constructs a new EnergyProblem object using the `connection`.
    This will call relevant functions to generate all input that is required for the model creation.
    """
    function EnergyProblem(connection; model_parameters_file = "")
        model = JuMP.Model()

        graph, representative_periods, timeframe, groups, years =
            @timeit to "create_internal_structure" create_internal_structures(connection)

        variables = @timeit to "compute_variables_indices" compute_variables_indices(connection)

        constraints =
            @timeit to "compute_constraints_indices" compute_constraints_indices(connection)

        energy_problem = new(
            connection,
            graph,
            variables,
            constraints,
            representative_periods,
            timeframe,
            groups,
            years,
            ModelParameters(connection, model_parameters_file),
            nothing,
            nothing,
            false,
            NaN,
            JuMP.OPTIMIZE_NOT_CALLED,
        )

        return energy_problem
    end
end

function Base.show(io::IO, ep::EnergyProblem)
    status_model_creation = !isnothing(ep.model)
    status_model_solved = ep.solved

    println(io, "EnergyProblem:")
    if status_model_creation
        println(io, "  - Model created!")
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
        println(io, "    - Termination status: ", ep.termination_status)
        println(io, "    - Objective value: ", ep.objective_value)
    elseif !status_model_solved && ep.termination_status == JuMP.INFEASIBLE
        println(io, "  - Model is infeasible!")
    else
        println(io, "  - Model not solved!")
    end
end
