export create_model!, create_model

"""
    create_model!(energy_problem; verbose = false)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    graph = energy_problem.graph
    representative_periods = energy_problem.representative_periods
    variables = energy_problem.variables
    constraints = energy_problem.constraints
    timeframe = energy_problem.timeframe
    groups = energy_problem.groups
    model_parameters = energy_problem.model_parameters
    years = energy_problem.years
    sets = create_sets(graph, years)
    energy_problem.model = @timeit to "create_model" create_model(
        energy_problem.db_connection,
        graph,
        sets,
        variables,
        constraints,
        representative_periods,
        years,
        timeframe,
        groups,
        model_parameters;
        kwargs...,
    )
    energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
    energy_problem.solved = false
    energy_problem.objective_value = NaN

    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes, timeframe, groups; write_lp_file = false, enable_names = true)

Create the energy model given the `graph`, `representative_periods`, dictionary of `dataframes` (created by [`construct_dataframes`](@ref)), timeframe, and groups.
"""
function create_model(
    connection,
    graph,
    sets,
    variables,
    constraints,
    representative_periods,
    years,
    timeframe,
    groups,
    model_parameters;
    write_lp_file = false,
    enable_names = true,
)
    # Maximum timestep
    Tmax = only(
        row[1] for
        row in DuckDB.query(connection, "SELECT MAX(num_timesteps) FROM rep_periods_data")
    )

    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    ## Model
    model = JuMP.Model()

    JuMP.set_string_names_on_creation(model, enable_names)

    ## Variables
    @timeit to "add_flow_variables!" add_flow_variables!(model, variables)
    @timeit to "add_investment_variables!" add_investment_variables!(model, graph, sets, variables)
    @timeit to "add_unit_commitment_variables!" add_unit_commitment_variables!(
        model,
        sets,
        variables,
    )
    @timeit to "add_storage_variables!" add_storage_variables!(model, graph, sets, variables)

    ## Add expressions to dataframes
    # TODO: What will improve this? Variables (#884)?, Constraints?
    add_expressions_to_constraints!(
        variables,
        constraints,
        model,
        expression_workspace,
        representative_periods,
        timeframe,
        graph,
    )

    ## Expressions for multi-year investment
    create_multi_year_expressions!(model, graph, sets, variables)

    ## Expressions for storage assets
    add_storage_expressions!(model, graph, sets, variables)

    ## Expressions for the objective function
    add_objective!(model, variables, graph, representative_periods, sets, model_parameters)

    # TODO: Pass sets instead of the explicit values
    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        model,
        variables,
        constraints,
        graph,
        sets,
    )

    @timeit to "add_energy_constraints!" add_energy_constraints!(model, constraints, graph)

    @timeit to "add_consumer_constraints!" add_consumer_constraints!(
        model,
        constraints,
        graph,
        sets,
    )

    @timeit to "add_storage_constraints!" add_storage_constraints!(
        model,
        variables,
        constraints,
        graph,
    )

    @timeit to "add_hub_constraints!" add_hub_constraints!(model, constraints, sets)

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(model, constraints, sets)

    @timeit to "add_transport_constraints!" add_transport_constraints!(
        model,
        variables,
        graph,
        sets,
    )

    if !isempty(groups)
        @timeit to "add_group_constraints!" add_group_constraints!(
            model,
            variables,
            graph,
            sets,
            groups,
        )
    end

    if !isempty(constraints[:units_on_and_outflows].indices)
        @timeit to "add_ramping_constraints!" add_ramping_constraints!(
            model,
            variables,
            constraints,
            graph,
            sets,
        )
    end

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
