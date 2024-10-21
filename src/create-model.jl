export create_model!, create_model

"""
    create_model!(energy_problem; verbose = false)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    elapsed_time_create_model = @elapsed begin
        graph = energy_problem.graph
        representative_periods = energy_problem.representative_periods
        variables = energy_problem.variables
        timeframe = energy_problem.timeframe
        groups = energy_problem.groups
        model_parameters = energy_problem.model_parameters
        years = energy_problem.years
        dataframes = energy_problem.dataframes
        sets = create_sets(graph, years)
        energy_problem.model = @timeit to "create_model" create_model(
            graph,
            sets,
            variables,
            representative_periods,
            dataframes,
            years,
            timeframe,
            groups,
            model_parameters;
            kwargs...,
        )
        energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
        energy_problem.solved = false
        energy_problem.objective_value = NaN
    end

    energy_problem.timings["creating the model"] = elapsed_time_create_model

    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes, timeframe, groups; write_lp_file = false)

Create the energy model given the `graph`, `representative_periods`, dictionary of `dataframes` (created by [`construct_dataframes`](@ref)), timeframe, and groups.
"""
function create_model(
    graph,
    sets,
    variables,
    representative_periods,
    dataframes,
    years,
    timeframe,
    groups,
    model_parameters;
    write_lp_file = false,
)
    # Maximum timestep
    Tmax = maximum(last(rp.timesteps) for year in sets.Y for rp in representative_periods[year])

    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    # Unpacking dataframes
    @timeit to "unpacking dataframes" begin
        df_flows = dataframes[:flows]
        df_units_on = dataframes[:units_on]
        df_units_on_and_outflows = dataframes[:units_on_and_outflows]
        df_storage_intra_rp_balance_grouped =
            DataFrames.groupby(dataframes[:storage_level_intra_rp], [:asset, :rep_period, :year])
        df_storage_inter_rp_balance_grouped =
            DataFrames.groupby(dataframes[:storage_level_inter_rp], [:asset, :year])
    end

    # Unpacking dataframes with variable indices
    @timeit to "unpacking variable indices" begin
        storage_level_intra_rp_indices = variables[:storage_level_intra_rp].indices
        storage_level_inter_rp_indices = variables[:storage_level_inter_rp].indices
        is_charging_indices = variables[:is_charging].indices
    end

    ## Model
    model = JuMP.Model()

    ## Variables
    @timeit to "add_flow_variables!" add_flow_variables!(model, dataframes)
    @timeit to "add_investment_variables!" add_investment_variables!(model, graph, sets)
    @timeit to "add_unit_commitment_variables!" add_unit_commitment_variables!(
        model,
        dataframes,
        sets,
    )
    @timeit to "add_storage_variables!" add_storage_variables!(
        model,
        graph,
        sets,
        storage_level_intra_rp_indices,
        storage_level_inter_rp_indices,
        is_charging_indices,
    )

    # TODO: This should change heavily, so I just moved things to the function and unpack them here from model
    assets_decommission_compact_method = model[:assets_decommission_compact_method]
    assets_decommission_simple_method = model[:assets_decommission_simple_method]
    assets_decommission_energy_simple_method = model[:assets_decommission_energy_simple_method]
    assets_investment = model[:assets_investment]
    assets_investment_energy = model[:assets_investment_energy]
    flow = model[:flow]
    flows_decommission_using_simple_method = model[:flows_decommission_using_simple_method]
    flows_investment = model[:flows_investment]
    storage_level_inter_rp = model[:storage_level_inter_rp]
    storage_level_intra_rp = model[:storage_level_intra_rp]

    ## Add expressions to dataframes
    # TODO: What will improve this? Variables (#884)?, Constraints?
    (
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
        incoming_flow_lowest_storage_resolution_intra_rp,
        outgoing_flow_lowest_storage_resolution_intra_rp,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
        incoming_flow_highest_in_resolution,
        outgoing_flow_highest_out_resolution,
        incoming_flow_storage_inter_rp_balance,
        outgoing_flow_storage_inter_rp_balance,
    ) = add_expressions_to_dataframe!(
        dataframes,
        model,
        expression_workspace,
        representative_periods,
        timeframe,
        graph,
        is_charging_indices,
    )

    ## Expressions for multi-year investment
    create_multi_year_expressions!(model, graph, sets)
    accumulated_flows_export_units = model[:accumulated_flows_export_units]
    accumulated_flows_import_units = model[:accumulated_flows_import_units]
    accumulated_initial_units = model[:accumulated_initial_units]
    accumulated_investment_units_using_simple_method =
        model[:accumulated_investment_units_using_simple_method]
    accumulated_units = model[:accumulated_units]
    accumulated_units_compact_method = model[:accumulated_units_compact_method]
    accumulated_units_simple_method = model[:accumulated_units_simple_method]

    ## Expressions for storage assets
    add_storage_expressions!(model, graph, sets)
    accumulated_energy_units_simple_method = model[:accumulated_energy_units_simple_method]
    accumulated_energy_capacity = model[:accumulated_energy_capacity]

    ## Expressions for the objective function
    add_objective!(model, graph, dataframes, representative_periods, sets, model_parameters)

    # TODO: Pass sets instead of the explicit values
    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        model,
        graph,
        dataframes,
        df_flows,
        flow,
        sets,
        accumulated_initial_units,
        accumulated_investment_units_using_simple_method,
        accumulated_units,
        accumulated_units_compact_method,
        outgoing_flow_highest_out_resolution,
        incoming_flow_highest_in_resolution,
    )

    @timeit to "add_energy_constraints!" add_energy_constraints!(model, graph, dataframes)

    @timeit to "add_consumer_constraints!" add_consumer_constraints!(
        model,
        graph,
        dataframes,
        sets,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_storage_constraints!" add_storage_constraints!(
        model,
        graph,
        dataframes,
        accumulated_energy_capacity,
        incoming_flow_lowest_storage_resolution_intra_rp,
        outgoing_flow_lowest_storage_resolution_intra_rp,
        df_storage_intra_rp_balance_grouped,
        df_storage_inter_rp_balance_grouped,
        storage_level_intra_rp,
        storage_level_inter_rp,
        incoming_flow_storage_inter_rp_balance,
        outgoing_flow_storage_inter_rp_balance,
    )

    @timeit to "add_hub_constraints!" add_hub_constraints!(
        model,
        dataframes,
        sets,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(
        model,
        dataframes,
        sets,
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
    )

    @timeit to "add_transport_constraints!" add_transport_constraints!(
        model,
        graph,
        df_flows,
        flow,
        sets,
        accumulated_flows_export_units,
        accumulated_flows_import_units,
    )

    @timeit to "add_investment_constraints!" add_investment_constraints!(
        graph,
        sets,
        assets_investment,
        assets_investment_energy,
        flows_investment,
    )

    if !isempty(groups)
        @timeit to "add_group_constraints!" add_group_constraints!(
            model,
            graph,
            sets,
            assets_investment,
            groups,
        )
    end

    if !isempty(dataframes[:units_on_and_outflows])
        @timeit to "add_ramping_constraints!" add_ramping_constraints!(
            model,
            graph,
            df_units_on_and_outflows,
            df_units_on,
            dataframes[:highest_out],
            outgoing_flow_highest_out_resolution,
            accumulated_units,
            sets,
        )
    end

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
