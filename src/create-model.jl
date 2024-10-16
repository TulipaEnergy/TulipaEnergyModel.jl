export create_model!, create_model, construct_dataframes

"""
    create_model!(energy_problem; verbose = false)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    elapsed_time_create_model = @elapsed begin
        graph = energy_problem.graph
        representative_periods = energy_problem.representative_periods
        constraints_partitions = energy_problem.constraints_partitions
        timeframe = energy_problem.timeframe
        groups = energy_problem.groups
        model_parameters = energy_problem.model_parameters
        years = energy_problem.years
        energy_problem.dataframes = @timeit to "construct_dataframes" construct_dataframes(
            graph,
            representative_periods,
            constraints_partitions,
            years,
        )
        energy_problem.model = @timeit to "create_model" create_model(
            graph,
            representative_periods,
            energy_problem.dataframes,
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
    representative_periods,
    dataframes,
    years,
    timeframe,
    groups,
    model_parameters;
    write_lp_file = false,
)
    Y = [year.id for year in years if year.is_milestone]
    V_all = [year.id for year in years]
    V_non_milestone = [year.id for year in years if !year.is_milestone]

    # Maximum timestep
    Tmax = maximum(last(rp.timesteps) for year in Y for rp in representative_periods[year])

    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    ## Sets unpacking
    @timeit to "unpacking and creating sets" begin
        A   = MetaGraphsNext.labels(graph) |> collect
        F   = MetaGraphsNext.edge_labels(graph) |> collect
        Ac  = filter_graph(graph, A, "consumer", :type)
        Ap  = filter_graph(graph, A, "producer", :type)
        As  = filter_graph(graph, A, "storage", :type)
        Ah  = filter_graph(graph, A, "hub", :type)
        Acv = filter_graph(graph, A, "conversion", :type)
        Ft  = filter_graph(graph, F, true, :is_transport)

        # Create subsets of assets by investable
        Ai = Dict(y => filter_graph(graph, A, true, :investable, y) for y in Y)
        Fi = Dict(y => filter_graph(graph, F, true, :investable, y) for y in Y)

        # Create a subset of years by investable assets, i.e., inverting Ai
        Yi = Dict(
            a => [y for y in Y if a in Ai[y]] for a in A if any(graph[a].investable[y] for y in Y)
        )

        # Create subsets of investable/decommissionable assets by investment method
        investable_assets_using_simple_method =
            Dict(y => Ai[y] ∩ filter_graph(graph, A, "simple", :investment_method) for y in Y)
        decommissionable_assets_using_simple_method =
            filter_graph(graph, A, "simple", :investment_method)

        investable_assets_using_compact_method =
            Dict(y => Ai[y] ∩ filter_graph(graph, A, "compact", :investment_method) for y in Y)
        decommissionable_assets_using_compact_method =
            filter_graph(graph, A, "compact", :investment_method)

        # Create dicts for the start year of investments that are accumulated in year y
        starting_year_using_simple_method = Dict(
            (y, a) => y - graph[a].technical_lifetime + 1 for y in Y for
            a in decommissionable_assets_using_simple_method
        )

        starting_year_using_compact_method = Dict(
            (y, a) => y - graph[a].technical_lifetime + 1 for y in Y for
            a in decommissionable_assets_using_compact_method
        )

        starting_year_flows_using_simple_method =
            Dict((y, (u, v)) => y - graph[u, v].technical_lifetime + 1 for y in Y for (u, v) in Ft)

        # Create a subset of decommissionable_assets_using_compact_method: existing assets invested in non-milestone years
        existing_assets_by_year_using_compact_method = Dict(
            y =>
                [
                    a for a in decommissionable_assets_using_compact_method for
                    inner_dict in values(graph[a].initial_units) for
                    k in keys(inner_dict) if k == y && inner_dict[k] != 0
                ] |> unique for y in V_all
        )

        # Create sets of tuples for decommission variables/accumulated capacity of compact method

        # Create conditions for decommission variables
        # Cond1: asset a invested in year v has to be operational at milestone year y
        # Cond2: invested in non-milestone years (i.e., initial units from non-milestone years), or
        # Cond3: invested in investable milestone years, or initial units from milestone years
        cond1_domain_decommission_variables(a, y, v) =
            starting_year_using_compact_method[y, a] ≤ v < y
        cond2_domain_decommission_variables(a, v) =
            (v in V_non_milestone && a in existing_assets_by_year_using_compact_method[v])
        cond3_domain_decommission_variables(a, v) =
            v in Y &&
            (a in investable_assets_using_compact_method[v] || (graph[a].initial_units[v][v] != 0))

        decommission_set_using_compact_method = [
            (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
            v in V_all if cond1_domain_decommission_variables(a, y, v) && (
                cond2_domain_decommission_variables(a, v) ||
                cond3_domain_decommission_variables(a, v)
            )
        ]

        # Create conditions for accumulated units compact method
        # Cond1: asset a invested in year v has to be operational at milestone year y
        # Note it is different from cond1_domain_decommission_variables because here, we allow accumulation at the year of investment
        # Cond2: same as cond2_domain_decommission_variables(a, v)
        # Cond3: same as cond3_domain_decommission_variables(a, v)
        cond1_domain_accumulated_units_using_compact_method(a, y, v) =
            starting_year_using_compact_method[y, a] ≤ v ≤ y

        accumulated_set_using_compact_method = [
            (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
            v in V_all if cond1_domain_accumulated_units_using_compact_method(a, y, v) && (
                cond2_domain_decommission_variables(a, v) ||
                cond3_domain_decommission_variables(a, v)
            )
        ]

        # Create a lookup set for compact method
        accumulated_set_using_compact_method_lookup = Dict(
            (a, y, v) => idx for
            (idx, (a, y, v)) in enumerate(accumulated_set_using_compact_method)
        )

        # Create subsets of storage assets
        Ase = Dict(y => As ∩ filter_graph(graph, A, true, :storage_method_energy, y) for y in Y)
        Asb = Dict(
            y =>
                As ∩ filter_graph(
                    graph,
                    A,
                    ["binary", "relaxed_binary"],
                    :use_binary_storage_method,
                    y,
                ) for y in Y
        )

        # Create subsets of assets for ramping and unit commitment for producers and conversion assets
        Ar = Dict(y => (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :ramping, y) for y in Y)
        Auc = Dict(y => (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :unit_commitment, y) for y in Y)
        Auc_integer =
            Dict(y => Auc[y] ∩ filter_graph(graph, A, true, :unit_commitment_integer, y) for y in Y)
        Auc_basic = Dict(
            y => Auc[y] ∩ filter_graph(graph, A, "basic", :unit_commitment_method, y) for y in Y
        )

        # TODO: Create a better structure if this is still necessary later
        sets = (; # This is a NamedTuple
            A,
            Ai,
            Ar,
            Asb,
            Ase,
            Auc,
            Auc_basic,
            Auc_integer,
            F,
            Fi,
            Ft,
            V_all,
            V_non_milestone,
            Y,
            decommission_set_using_compact_method,
            decommissionable_assets_using_compact_method,
            decommissionable_assets_using_simple_method,
            existing_assets_by_year_using_compact_method,
        )
    end
    # Unpacking dataframes
    @timeit to "unpacking dataframes" begin
        df_flows = dataframes[:flows]
        df_is_charging = dataframes[:lowest_in_out]
        df_units_on = dataframes[:units_on]
        df_units_on_and_outflows = dataframes[:units_on_and_outflows]
        df_storage_intra_rp_balance_grouped = DataFrames.groupby(
            dataframes[:lowest_storage_level_intra_rp],
            [:asset, :rep_period, :year],
        )
        df_storage_inter_rp_balance_grouped =
            DataFrames.groupby(dataframes[:storage_level_inter_rp], [:asset, :year])
    end

    ## Model
    model = JuMP.Model()

    ## Variables
    create_variables!(model, graph, dataframes, sets)
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
    )

    ## Expressions for multi-year investment
    @timeit to "multi-year investment" begin
        accumulated_initial_units = @expression(
            model,
            accumulated_initial_units[a in A, y in Y],
            sum(values(graph[a].initial_units[y]))
        )

        ### Expressions for multi-year investment simple method
        accumulated_investment_units_using_simple_method = @expression(
            model,
            accumulated_investment_units_using_simple_method[
                a ∈ decommissionable_assets_using_simple_method,
                y in Y,
            ],
            sum(
                assets_investment[yy, a] for
                yy in Y if a ∈ investable_assets_using_simple_method[yy] &&
                starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_using_simple_method[
                a ∈ decommissionable_assets_using_simple_method,
                y in Y,
            ],
            sum(
                assets_decommission_simple_method[yy, a] for
                yy in Y if starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_units_simple_method[a ∈ decommissionable_assets_using_simple_method, y ∈ Y],
            accumulated_initial_units[a, y] +
            accumulated_investment_units_using_simple_method[a, y] -
            accumulated_decommission_units_using_simple_method[a, y]
        )

        ### Expressions for multi-year investment compact method
        @expression(
            model,
            accumulated_decommission_units_using_compact_method[(
                a,
                y,
                v,
            ) in accumulated_set_using_compact_method],
            sum(
                assets_decommission_compact_method[(a, yy, v)] for
                yy in Y if v ≤ yy ≤ y && (a, yy, v) in decommission_set_using_compact_method
            )
        )
        cond1(a, y, v) = a in existing_assets_by_year_using_compact_method[v]
        cond2(a, y, v) = v in Y && a in investable_assets_using_compact_method[v]
        accumulated_units_compact_method =
            model[:accumulated_units_compact_method] = JuMP.AffExpr[
                if cond1(a, y, v) && cond2(a, y, v)
                    @expression(
                        model,
                        graph[a].initial_units[y][v] + assets_investment[v, a] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                elseif cond1(a, y, v) && !cond2(a, y, v)
                    @expression(
                        model,
                        graph[a].initial_units[y][v] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                elseif !cond1(a, y, v) && cond2(a, y, v)
                    @expression(
                        model,
                        assets_investment[v, a] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                else
                    @expression(model, 0.0)
                end for (a, y, v) in accumulated_set_using_compact_method
            ]

        ### Expressions for multi-year investment for accumulated units no matter the method
        accumulated_units_lookup =
            Dict((a, y) => idx for (idx, (a, y)) in enumerate((aa, yy) for aa in A for yy in Y))

        accumulated_units =
            model[:accumulated_units] = JuMP.AffExpr[
                if a in decommissionable_assets_using_simple_method
                    @expression(model, accumulated_units_simple_method[a, y])
                elseif a in decommissionable_assets_using_compact_method
                    @expression(
                        model,
                        sum(
                            accumulated_units_compact_method[accumulated_set_using_compact_method_lookup[(
                                a,
                                y,
                                v,
                            )]] for
                            v in V_all if (a, y, v) in accumulated_set_using_compact_method
                        )
                    )
                else
                    @expression(model, sum(values(graph[a].initial_units[y])))
                end for a in A for y in Y
            ]
        ## Expressions for transport assets
        @expression(
            model,
            accumulated_investment_units_transport_using_simple_method[y ∈ Y, (u, v) ∈ Ft],
            sum(
                flows_investment[yy, (u, v)] for yy in Y if
                (u, v) ∈ Fi[yy] && starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_transport_using_simple_method[y ∈ Y, (u, v) ∈ Ft],
            sum(
                flows_decommission_using_simple_method[yy, (u, v)] for
                yy in Y if starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_flows_export_units[y ∈ Y, (u, v) ∈ Ft],
            sum(values(graph[u, v].initial_export_units[y])) +
            accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
            accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
        )
        @expression(
            model,
            accumulated_flows_import_units[y ∈ Y, (u, v) ∈ Ft],
            sum(values(graph[u, v].initial_import_units[y])) +
            accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
            accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
        )
    end

    ## Expressions for storage assets
    @timeit to "add_expressions_for_storage" begin
        @expression(
            model,
            accumulated_energy_units_simple_method[
                y ∈ Y,
                a ∈ Ase[y]∩decommissionable_assets_using_simple_method,
            ],
            sum(values(graph[a].initial_storage_units[y])) + sum(
                assets_investment_energy[yy, a] for
                yy in Y if a ∈ (Ase[yy] ∩ investable_assets_using_simple_method[yy]) &&
                starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            ) - sum(
                assets_decommission_energy_simple_method[yy, a] for
                yy in Y if a ∈ Ase[yy] && starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_energy_capacity[y ∈ Y, a ∈ As],
            if graph[a].storage_method_energy[y] &&
               a ∈ Ase[y] ∩ decommissionable_assets_using_simple_method
                graph[a].capacity_storage_energy * accumulated_energy_units_simple_method[y, a]
            else
                (
                    graph[a].capacity_storage_energy *
                    sum(values(graph[a].initial_storage_units[y])) +
                    if a ∈ Ai[y] ∩ decommissionable_assets_using_simple_method
                        graph[a].energy_to_power_ratio[y] *
                        graph[a].capacity *
                        (
                            accumulated_investment_units_using_simple_method[a, y] -
                            accumulated_decommission_units_using_simple_method[a, y]
                        )
                    else
                        0.0
                    end
                )
            end
        )
    end

    ## Expressions for the objective function
    @timeit to "objective" begin
        # Create a dict of weights for assets investment discounts
        weight_for_assets_investment_discounts =
            calculate_weight_for_investment_discounts(graph, Y, Ai, A, model_parameters)

        # Create a dict of weights for flows investment discounts
        weight_for_flows_investment_discounts =
            calculate_weight_for_investment_discounts(graph, Y, Fi, Ft, model_parameters)

        # Create a dict of intervals for milestone years
        intervals_for_milestone_years = create_intervals_for_years(Y)

        # Create a dict of operation discounts only for milestone years
        operation_discounts_for_milestone_years = Dict(
            y => 1 / (1 + model_parameters.discount_rate)^(y - model_parameters.discount_year)
            for y in Y
        )

        # Create a dict of operation discounts for milestone years including in-between years
        weight_for_operation_discounts = Dict(
            y => operation_discounts_for_milestone_years[y] * intervals_for_milestone_years[y]
            for y in Y
        )

        assets_investment_cost = @expression(
            model,
            sum(
                weight_for_assets_investment_discounts[(y, a)] *
                graph[a].investment_cost[y] *
                graph[a].capacity *
                assets_investment[y, a] for y in Y for a in Ai[y]
            )
        )

        assets_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost[y] *
                graph[a].capacity *
                accumulated_units_simple_method[a, y] for y in Y for
                a in decommissionable_assets_using_simple_method
            ) + sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost[v] *
                graph[a].capacity *
                accm for (accm, (a, y, v)) in
                zip(accumulated_units_compact_method, accumulated_set_using_compact_method)
            )
        )

        storage_assets_energy_investment_cost = @expression(
            model,
            sum(
                weight_for_assets_investment_discounts[(y, a)] *
                graph[a].investment_cost_storage_energy[y] *
                graph[a].capacity_storage_energy *
                assets_investment_energy[y, a] for y in Y for a in Ase[y] ∩ Ai[y]
            )
        )

        storage_assets_energy_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost_storage_energy[y] *
                graph[a].capacity_storage_energy *
                accumulated_energy_units_simple_method[y, a] for y in Y for
                a in Ase[y] ∩ decommissionable_assets_using_simple_method
            )
        )

        flows_investment_cost = @expression(
            model,
            sum(
                weight_for_flows_investment_discounts[(y, (u, v))] *
                graph[u, v].investment_cost[y] *
                graph[u, v].capacity *
                flows_investment[y, (u, v)] for y in Y for (u, v) in Fi[y]
            )
        )

        flows_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] * graph[u, v].fixed_cost[y] / 2 *
                graph[u, v].capacity *
                (
                    accumulated_flows_export_units[y, (u, v)] +
                    accumulated_flows_import_units[y, (u, v)]
                ) for y in Y for (u, v) in Fi[y]
            )
        )

        flows_variable_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[row.year] *
                representative_periods[row.year][row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period, representative_periods[row.year]) *
                graph[row.from, row.to].variable_cost[row.year] *
                row.flow for row in eachrow(df_flows)
            )
        )

        units_on_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[row.year] *
                representative_periods[row.year][row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period, representative_periods[row.year]) *
                graph[row.asset].units_on_cost[row.year] *
                row.units_on for row in eachrow(df_units_on) if
                !ismissing(graph[row.asset].units_on_cost[row.year])
            )
        )

        ## Objective function
        @objective(
            model,
            Min,
            assets_investment_cost +
            assets_fixed_cost +
            storage_assets_energy_investment_cost +
            storage_assets_energy_fixed_cost +
            flows_investment_cost +
            flows_fixed_cost +
            flows_variable_cost +
            units_on_cost
        )
    end

    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        model,
        graph,
        Ap,
        Acv,
        As,
        dataframes,
        df_flows,
        flow,
        Y,
        Ai,
        decommissionable_assets_using_simple_method,
        decommissionable_assets_using_compact_method,
        V_all,
        accumulated_units_lookup,
        accumulated_set_using_compact_method_lookup,
        Asb,
        accumulated_initial_units,
        accumulated_investment_units_using_simple_method,
        accumulated_units,
        accumulated_units_compact_method,
        accumulated_set_using_compact_method,
        outgoing_flow_highest_out_resolution,
        incoming_flow_highest_in_resolution,
    )

    @timeit to "add_energy_constraints!" add_energy_constraints!(model, graph, dataframes)

    @timeit to "add_consumer_constraints!" add_consumer_constraints!(
        model,
        graph,
        dataframes,
        Ac,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_storage_constraints!" add_storage_constraints!(
        model,
        graph,
        dataframes,
        Ai,
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
        Ah,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(
        model,
        dataframes,
        Acv,
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
    )

    @timeit to "add_transport_constraints!" add_transport_constraints!(
        model,
        graph,
        df_flows,
        flow,
        Ft,
        accumulated_flows_export_units,
        accumulated_flows_import_units,
        flows_investment,
    )

    @timeit to "add_investment_constraints!" add_investment_constraints!(
        graph,
        Y,
        Ai,
        Ase,
        Fi,
        assets_investment,
        assets_investment_energy,
        flows_investment,
    )

    if !isempty(groups)
        @timeit to "add_group_constraints!" add_group_constraints!(
            model,
            graph,
            Y,
            Ai,
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
            accumulated_units_lookup,
            accumulated_units,
            Ai,
            Auc,
            Auc_basic,
            Ar,
        )
    end

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
