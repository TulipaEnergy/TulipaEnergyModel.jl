export create_model!, create_model

"""
    create_model!(energy_problem; kwargs...)

Create the internal model of a [`TulipaEnergyModel.EnergyProblem`](@ref).
Any keyword argument will be passed to the underlying [`create_model`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    energy_problem.model, energy_problem.expressions = @timeit to "create_model" create_model(
        energy_problem.db_connection,
        energy_problem.variables,
        energy_problem.constraints,
        energy_problem.profiles,
        energy_problem.model_parameters;
        kwargs...,
    )
    energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
    energy_problem.solved = false
    energy_problem.objective_value = NaN

    return energy_problem
end

"""
    model, expressions = create_model(
        connection,
        variables,
        constraints,
        profiles,
        model_parameters;
        optimizer = HiGHS.Optimizer,
        optimizer_parameters = default_parameters(optimizer),
        model_file_name = "",
        enable_names = true
        direct_model = false,
    )

Create the energy model manually. We recommend using [`create_model!`](@ref) instead.

The `optimizer` argument should be an MILP solver from the JuMP
list of [supported solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
By default we use HiGHS.

The keyword argument `optimizer_parameters` should be passed as a dictionary of `key => value` pairs.
These can be created manually, obtained using [`default_parameters`](@ref), or read from a file
using [`read_parameters_from_file`](@ref).

```julia
parameters = Dict{String,Any}("presolve" => "on", "time_limit" => 60.0, "output_flag" => true)
solve_model(model; optimizer = HiGHS.Optimizer, optimizer_parameters = parameters)
```

Set `enable_names = false` to avoid assigning names to variables and constraints, which improves speed but reduces the readability of log messages.
For more information, see [`JuMP.set_string_names_on_creation`](https://jump.dev/JuMP.jl/stable/api/JuMP/#set_string_names_on_creation).

Set `direct_model = true` to create a JuMP `direct_model` using `optimizer_with_attributes`, which has memory improvements.
For more information, see [`JuMP.direct_model`](https://jump.dev/JuMP.jl/stable/api/JuMP/#direct_model).

"""
function create_model(
    connection,
    variables,
    constraints,
    profiles,
    model_parameters;
    optimizer = HiGHS.Optimizer,
    optimizer_parameters = default_parameters(optimizer),
    model_file_name = "",
    enable_names = true,
    direct_model = false,
)
    ## Optimizer
    optimizer_with_attributes = JuMP.optimizer_with_attributes(optimizer, optimizer_parameters...)

    ## Model
    if direct_model
        model = JuMP.direct_model(optimizer_with_attributes)
    else
        model = JuMP.Model(optimizer_with_attributes)
    end

    JuMP.set_string_names_on_creation(model, enable_names)

    ## Variables
    @timeit to "add_flow_variables!" add_flow_variables!(connection, model, variables)
    @timeit to "add_vintage_flow_variables!" add_vintage_flow_variables!(
        connection,
        model,
        variables,
    )
    @timeit to "add_investment_variables!" add_investment_variables!(model, variables)
    @timeit to "add_decommission_variables!" add_decommission_variables!(model, variables)
    @timeit to "add_unit_commitment_variables!" add_unit_commitment_variables!(model, variables)
    @timeit to "add_power_flow_variables!" add_power_flow_variables!(model, variables)
    @timeit to "add_storage_variables!" add_storage_variables!(connection, model, variables)

    @timeit to "add_expressions_to_constraints!" add_expressions_to_constraints!(
        connection,
        variables,
        constraints,
    )

    ## Expressions
    expressions = Dict{Symbol,TulipaExpression}()

    ## Expressions for multi-year investment
    @timeit to "create_multi_year_expressions!" create_multi_year_expressions!(
        connection,
        model,
        variables,
        expressions,
    )

    ## Expressions for storage assets
    @timeit to "add_storage_expressions!" add_storage_expressions!(connection, model, expressions)

    ## Expressions for the objective function
    @timeit to "add_objective!" add_objective!(
        connection,
        model,
        variables,
        expressions,
        model_parameters,
    )

    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        connection,
        model,
        expressions,
        constraints,
        profiles,
    )

    @timeit to "add_energy_constraints!" add_energy_constraints!(
        connection,
        model,
        constraints,
        profiles,
    )

    @timeit to "add_consumer_constraints!" add_consumer_constraints!(
        connection,
        model,
        constraints,
        profiles,
    )

    @timeit to "add_storage_constraints!" add_storage_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
        profiles,
    )

    @timeit to "add_hub_constraints!" add_hub_constraints!(model, constraints)

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(
        connection,
        model,
        constraints,
    )

    @timeit to "add_transport_constraints!" add_transport_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
        profiles,
    )

    @timeit to "add_group_constraints!" add_group_constraints!(
        connection,
        model,
        variables,
        constraints,
    )

    @timeit to "add_ramping_constraints!" add_ramping_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
        profiles,
    )

    @timeit to "add_flows_relationships_constraints!" add_flows_relationships_constraints!(
        connection,
        model,
        variables,
        constraints,
    )

    @timeit to "add_dc_power_flow_constraints!" add_dc_power_flow_constraints!(
        connection,
        model,
        variables,
        constraints,
        model_parameters,
    )

    @timeit to "add_vintage_flow_sum_constraints!" add_vintage_flow_sum_constraints!(
        connection,
        model,
        variables,
        constraints,
    )

    if model_file_name != ""
        @timeit to "save model file" JuMP.write_to_file(model, model_file_name)
    end

    return model, expressions
end
