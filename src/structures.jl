export EnergyProblem,
    ProfileLookup,
    TulipaVariable,
    TulipaConstraint,
    TulipaExpression,
    PeriodsBlock,
    TimestepsBlock,
    attach_constraint!,
    attach_expression!,
    attach_coefficient!

const TimestepsBlock = UnitRange{Int}
const PeriodsBlock = UnitRange{Int}

const PeriodType = Symbol
const PERIOD_TYPES = [:rep_periods, :timeframe]

"""
    TulipaTabularIndex

Abstract structure for TulipaVariable, TulipaConstraint and TulipaExpression.
All deriving types must satisfy:

- Have fields
    - `indices::DuckDB.QueryResult`
    - `table_name`::String
"""
abstract type TulipaTabularIndex end

function get_num_rows(connection, table_name::Union{String,Symbol})
    return get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT COUNT(*) FROM $table_name"),
    )::Int64
end

function get_num_rows(connection, object::TulipaTabularIndex)
    table_name = object.table_name
    return get_num_rows(connection, table_name)
end

"""
Structure to hold the JuMP variables for the TulipaEnergyModel
"""
mutable struct TulipaVariable <: TulipaTabularIndex
    indices::DuckDB.QueryResult
    table_name::String
    container::Vector{JuMP.VariableRef}

    function TulipaVariable(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name"),
            table_name,
            JuMP.VariableRef[],
        )
    end
end

"""
Structure to hold the JuMP constraints for the TulipaEnergyModel
"""
mutable struct TulipaConstraint <: TulipaTabularIndex
    indices::DuckDB.QueryResult
    table_name::String
    num_rows::Int
    constraint_names::Vector{Symbol}
    expressions::Dict{Symbol,Vector{JuMP.AffExpr}}
    coefficients::Dict{Symbol,Vector{Float64}}
    duals::Dict{Symbol,Vector{Float64}}

    function TulipaConstraint(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name"),
            table_name,
            get_single_element_from_query_and_ensure_its_only_one(
                DuckDB.query(connection, "SELECT COUNT(*) AS num_rows FROM $table_name"),
            ),
            Symbol[],
            Dict(),
            Dict(),
            Dict(),
        )
    end
end

"""
Structure to hold some JuMP expressions that are not attached to constraints but are attached to a table.
"""
mutable struct TulipaExpression <: TulipaTabularIndex
    indices::DuckDB.QueryResult
    table_name::String
    num_rows::Int
    expressions::Dict{Symbol,Vector{JuMP.AffExpr}}

    function TulipaExpression(connection, table_name::String)
        return new(
            DuckDB.query(connection, "SELECT * FROM $table_name"),
            table_name,
            get_single_element_from_query_and_ensure_its_only_one(
                DuckDB.query(connection, "SELECT COUNT(*) AS num_rows FROM $table_name"),
            ),
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
    # indices table in empty in [@constraint(...) for row in indices].
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
    cons_or_expr::TulipaTabularIndex,
    name::Symbol,
    container::Vector{JuMP.AffExpr},
)
    if length(container) != cons_or_expr.num_rows
        error("The number of expressions does not match the number of rows in the indices of $name")
    end
    cons_or_expr.expressions[name] = container
    return nothing
end

function attach_expression!(cons_or_expr::TulipaTabularIndex, name::Symbol, container)
    # This should be the empty case container = Any[] that happens when the
    # indices table in empty in [@constraint(...) for row in indices].
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
Structure to hold the dictionaries of profiles.
"""
mutable struct ProfileLookup
    # The integers here are Int32 because they are obtained directly from DuckDB
    #
    # rep_period[(asset, year, rep_period)]
    rep_period::Dict{Tuple{String,Int32,Int32},Vector{Float64}}

    # over_clustered_year[(asset, year)]
    over_clustered_year::Dict{Tuple{String,Int32},Vector{Float64}}
end

"""
    EnergyProblem

Structure to hold all parts of an energy problem. It is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

# Fields

- `db_connection`: A DuckDB connection to the input tables in the model.
- `variables`: A dictionary of [TulipaVariable](@ref TulipaVariable)s containing the variables of the model.
- `expressions`: A dictionary of [TulipaExpression](@ref TulipaExpression)s containing the expressions of the model attached to tables.
- `constraints`: A dictionary of [TulipaConstraint](@ref TulipaConstraint)s containing the constraints of the model.
- `profiles`: Holds the profiles per `rep_period` or `over_clustered_year` in dictionary format. See [ProfileLookup](@ref).
- `model_parameters`: A [ModelParameters](@ref ModelParameters) structure to store all the parameters that are exclusive of the model.
- `model`: A JuMP.Model object representing the optimization model.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem (Float64).
- `termination_status`: The termination status of the optimization model.

# Constructor

- `EnergyProblem(connection)`: Constructs a new `EnergyProblem` object with the given connection.
The `constraints_partitions` field is computed from the `representative_periods`, and the other
fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.
"""
mutable struct EnergyProblem
    db_connection::DuckDB.DB
    variables::Dict{Symbol,TulipaVariable}
    expressions::Dict{Symbol,TulipaExpression}
    constraints::Dict{Symbol,TulipaConstraint}
    profiles::ProfileLookup
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
        @timeit to "create_internal_structure" create_internal_tables!(connection)

        variables = @timeit to "compute_variables_indices" compute_variables_indices(connection)

        constraints =
            @timeit to "compute_constraints_indices" compute_constraints_indices(connection)

        profiles = @timeit to "prepare_profiles_structure" prepare_profiles_structure(connection)

        energy_problem = new(
            connection,
            variables,
            Dict(),
            constraints,
            profiles,
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
        println(io, "  - Model solved!")
        println(io, "    - Termination status: ", ep.termination_status)
        println(io, "    - Objective value: ", ep.objective_value)
    elseif !status_model_solved && ep.termination_status == JuMP.INFEASIBLE
        println(io, "  - Model is infeasible!")
    else
        println(io, "  - Model not solved!")
    end
end
