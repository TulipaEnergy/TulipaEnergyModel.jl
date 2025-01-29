export GraphAssetData,
    GraphFlowData,
    EnergyProblem,
    TulipaVariable,
    TulipaConstraint,
    RepresentativePeriod,
    PeriodsBlock,
    TimestepsBlock,
    Timeframe,
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

"""
Structure to hold the JuMP constraints for the TulipaEnergyModel
"""
mutable struct TulipaConstraint
    indices::DataFrame
    table_name::String
    num_rows::Int
    constraint_names::Vector{Symbol}
    expressions::Dict{Symbol,Vector{JuMP.AffExpr}}
    coefficients::Dict{Symbol,Vector{Float64}} # TODO: This was created only because of min_outgoing_flow_duration
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
            Dict(),
        )
    end
end

mutable struct TulipaExpression
    indices::DataFrame
    table_name::String
    num_rows::Int
    expressions::Dict{Symbol,Vector{JuMP.AffExpr}}

    function TulipaExpression(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name") |> DataFrame,
            table_name,
            only([
                row.num_rows for
                row in DuckDB.query(connection, "SELECT COUNT(*) AS num_rows FROM $table_name")
            ]),
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
    if length(container) != cons.num_rows
        error("The number of constraints does not match the number of rows in the indices of $name")
    end
    push!(cons.constraint_names, name)
    if haskey(model, name)
        error("model already has a constraint named $name")
    end
    model[name] = container
    return nothing
end

function attach_constraint!(model::JuMP.Model, cons::TulipaConstraint, name::Symbol, container)
    # This should be the empty case container = Any[] that happens when the
    # indices table in empty in [@constraint(...) for row in eachrow(indices)].
    # It resolves to [] so the element type cannot be inferred
    if length(container) > 0
        error(
            "This variant is supposed to capture empty containers. This container is not empty for $name",
        )
    end
    if cons.num_rows > 0
        error("The number of rows in indices table should be 0 for $name")
    end
    empty_container = JuMP.ConstraintRef{JuMP.Model,Missing,JuMP.ScalarShape}[]
    model[name] = empty_container
    return nothing
end

"""
    attach_expression!(cons_or_expr, name, container)
    attach_expression!(model, cons_or_expr, name, container)

Attach a expression named `name` stored in `container`, and optionally set `model[name] = container`.
This checks that the `container` length matches the stored `indices` number of rows.
"""
function attach_expression!(
    cons_or_expr::Union{TulipaConstraint,TulipaExpression},
    name::Symbol,
    container::Vector{JuMP.AffExpr},
)
    if length(container) != cons_or_expr.num_rows
        error("The number of expressions does not match the number of rows in the indices of $name")
    end
    cons_or_expr.expressions[name] = container
    return nothing
end

function attach_expression!(
    cons_or_expr::Union{TulipaConstraint,TulipaExpression},
    name::Symbol,
    container,
)
    # This should be the empty case container = Any[] that happens when the
    # indices table in empty in [@constraint(...) for row in eachrow(indices)].
    # It resolves to [] so the element type cannot be inferred
    if length(container) > 0
        error(
            "This variant is supposed to capture empty containers. This container is not empty for $name",
        )
    end
    if cons_or_expr.num_rows > 0
        error("The number of rows in indices table should be 0 for $name")
    end
    cons_or_expr.expressions[name] = JuMP.AffExpr[]
    return nothing
end

# Not used at the moment, but might be useful by the end of #642
# function attach_expression!(
#     model::JuMP.Model,
#     cons::TulipaConstraint,
#     name::Symbol,
#     container::Vector{JuMP.AffExpr},
# )
#     attach_expression!(cons, name, container)
#     if haskey(model, name)
#         error("model already has an expression named $name")
#     end
#     model[name] = container
#     return nothing
# end

"""
    attach_coefficient!(cons, name, container)

Attach a coefficient named `name` stored in `container`.
This checks that the `container` length matches the stored `indices` number of rows.
"""
function attach_coefficient!(cons::TulipaConstraint, name::Symbol, container)
    if length(container) != cons.num_rows
        error(
            "The number of coefficients does not match the number of rows in the indices of $name",
        )
    end
    cons.coefficients[name] = container
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

    # You don't need profiles to create the struct, so initiate it empty
    function GraphAssetData(args...)
        timeframe_profiles = Dict{Int,Dict{Int,Dict{String,Vector{Float64}}}}()
        rep_periods_profiles = Dict{Int,Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}}()
        return new(args..., timeframe_profiles, rep_periods_profiles)
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
end

function GraphFlowData(args...)
    return GraphFlowData(
        args...,
        Dict{Int,Dict{String,Vector{Float64}}}(),
        Dict{Int,Dict{Tuple{String,Int},Vector{Float64}}}(),
    )
end

mutable struct ProfileLookup
    # The integers here are Int32 because they are obtained directly from DuckDB
    #
    # rep_period[(asset, year, rep_period)]
    rep_period::Dict{Tuple{String,Int32,Int32},Vector{Float64}}

    # over_clustered_year[(asset, year)]
    over_clustered_year::Dict{Tuple{String,Int32},Vector{Float64}}
end

"""
Structure to hold all parts of an energy problem. It is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

# Fields
- `db_connection`: A DuckDB connection to the input tables in the model
- `graph`: The Graph object that defines the geometry of the energy problem.
- `model`: A JuMP.Model object representing the optimization model.
- `objective_value`: The objective value of the solved problem (Float64).
- `variables`: A [TulipaVariable](@ref TulipaVariable) structure to store all the information related to the variables in the model.
- `constraints`: A [TulipaConstraint](@ref TulipaConstraint) structure to store all the information related to the constraints in the model.
- `representative_periods`: A vector of [Representative Periods](@ref representative-periods).
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `termination_status`: The termination status of the optimization model.
- `timeframe`: A structure with the number of periods in the `representative_periods` and the mapping between the periods and their representatives.
- `model_parameters`: A [ModelParameters](@ref ModelParameters) structure to store all the parameters that are exclusive of the model.
- `years`: A vector with the information of all the milestone years.

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
    expressions::Dict{Symbol,TulipaExpression}
    constraints::Dict{Symbol,TulipaConstraint}
    profiles::ProfileLookup
    representative_periods::Dict{Int,Vector{RepresentativePeriod}}
    timeframe::Timeframe
    years::Vector{Year}
    model_parameters::ModelParameters
    model::Union{JuMP.Model,Nothing}
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

        graph, representative_periods, timeframe, years =
            @timeit to "create_internal_structure" create_internal_structures(connection)

        variables = @timeit to "compute_variables_indices" compute_variables_indices(connection)

        constraints =
            @timeit to "compute_constraints_indices" compute_constraints_indices(connection)

        profiles = @timeit to "prepare_profiles_structure" prepare_profiles_structure(connection)

        energy_problem = new(
            connection,
            graph,
            variables,
            Dict(),
            constraints,
            profiles,
            representative_periods,
            timeframe,
            years,
            ModelParameters(connection, model_parameters_file),
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
