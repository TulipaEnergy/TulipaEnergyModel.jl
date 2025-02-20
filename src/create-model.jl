export create_model!, create_model

"""
    create_model!(energy_problem; kwargs...)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
Any keyword argument will be passed to the underlyting [`create_model`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    energy_problem.model = @timeit to "create_model" create_model(
        energy_problem.db_connection,
        energy_problem.variables,
        energy_problem.expressions,
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
    model = create_model(
        connection,
        variables,
        expressions,
        constraints,
        profiles,
        model_parameters;
        write_lp_file = false,
        enable_names = true
    )

Create the energy model manually. We recommend using [`create_model!`](@ref) instead.
"""
function create_model(
    connection,
    variables,
    expressions,
    constraints,
    profiles,
    model_parameters;
    write_lp_file = false,
    enable_names = true,
)
    ## Model
    model = JuMP.Model()

    JuMP.set_string_names_on_creation(model, enable_names)

    ## Variables
    @timeit to "add_flow_variables!" add_flow_variables!(connection, model, variables)
    @timeit to "add_investment_variables!" add_investment_variables!(model, variables)
    @timeit to "add_unit_commitment_variables!" add_unit_commitment_variables!(model, variables)
    @timeit to "add_storage_variables!" add_storage_variables!(connection, model, variables)

    @timeit to "add_expressions_to_constraints!" add_expressions_to_constraints!(
        connection,
        variables,
        constraints,
    )

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

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(model, constraints)

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

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
