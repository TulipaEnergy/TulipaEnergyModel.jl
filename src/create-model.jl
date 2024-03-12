export create_model!, create_model, construct_dataframes

"""
    dataframes = construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,
        base_periods,
    )

Computes the data frames used to linearize the variables and constraints. These are used
internally in the model only.
"""
function construct_dataframes(graph, representative_periods, constraints_partitions, base_periods)
    A = labels(graph) |> collect
    F = edge_labels(graph) |> collect
    RP = 1:length(representative_periods)

    # Output object
    dataframes = Dict{Symbol,DataFrame}()

    # DataFrame to store the flow variables
    dataframes[:flows] = DataFrame(
        (
            (
                (
                    from = u,
                    to = v,
                    rp = rp,
                    time_block = time_block,
                    efficiency = graph[u, v].efficiency,
                ) for time_block ∈ graph[u, v].rep_periods_partitions[rp]
            ) for (u, v) ∈ F, rp ∈ RP
        ) |> Iterators.flatten,
    )
    dataframes[:flows].index = 1:size(dataframes[:flows], 1)

    for (key, partitions) in constraints_partitions
        if length(partitions) == 0
            # No data, but ensure schema is correct
            dataframes[key] = DataFrame(;
                asset = String[],
                rp = Int[],
                time_block = UnitRange{Int}[],
                index = Int[],
            )
            continue
        end

        # This construction should ensure the ordering of the time blocks for groups of (a, rp)
        df = DataFrame(
            (
                ((asset = a, rp = rp, time_block = time_block) for time_block ∈ partition) for
                ((a, rp), partition) in partitions
            ) |> Iterators.flatten,
        )
        df.index = 1:size(df, 1)
        dataframes[key] = df
    end

    # Dataframe to store the storage level between (inter) representative period variable (e.g., seasonal storage)
    #
    dataframes[:storage_level_inter_rp] = DataFrame(
        (
            (
                (asset = a, base_period_block = time_block) for
                time_block in graph[a].base_periods_partitions
            ) for a in A
        ) |> Iterators.flatten,
    )
    if size(dataframes[:storage_level_inter_rp], 1) == 0
        dataframes[:storage_level_inter_rp] =
            DataFrame(; asset = String[], base_period_block = UnitRange{Int}[])
    end
    dataframes[:storage_level_inter_rp].index = 1:size(dataframes[:storage_level_inter_rp], 1)

    return dataframes
end

"""
    add_expression_terms_intra_rp_constraints!(df_cons,
                                               df_flows,
                                               workspace,
                                               representative_periods,
                                               graph;
                                               use_highest_resolution = true,
                                               multiply_by_duration = true,
                                               )

Computes the incoming and outgoing expressions per row of df_cons for the constraints
that are within (intra) the representative period.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_terms_intra_rp_constraints!(
    df_cons,
    df_flows,
    workspace,
    representative_periods,
    graph;
    use_highest_resolution = true,
    multiply_by_duration = true,
)
    # Aggregating function: If the duration should NOT be taken into account, we have to compute unique appearances of the flows.
    # Otherwise, just use the sum
    agg = multiply_by_duration ? v -> sum(v) : v -> sum(unique(v))

    grouped_cons = groupby(df_cons, [:rp, :asset])

    # grouped_cons' asset will be matched with either to or from, depending on whether
    # we are filling incoming or outgoing flows
    cases = [
        (col_name = :incoming_flow, asset_match = :to, selected_assets = ["hub", "consumer"]),
        (
            col_name = :outgoing_flow,
            asset_match = :from,
            selected_assets = ["hub", "consumer", "producer"],
        ),
    ]

    for case in cases
        df_cons[!, case.col_name] .= AffExpr(0.0)
        grouped_flows = groupby(df_flows, [:rp, case.asset_match])
        for ((rp, asset), sub_df) in pairs(grouped_cons)
            if !haskey(grouped_flows, (rp, asset))
                continue
            end
            resolution = multiply_by_duration ? representative_periods[rp].resolution : 1.0
            for i in eachindex(workspace)
                workspace[i] = AffExpr(0.0)
            end
            # Store the corresponding flow in the workspace
            for row in eachrow(grouped_flows[(rp, asset)])
                asset = row[case.asset_match]
                for t ∈ row.time_block
                    # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                    # And when you want the highest resolution (which is asset type-agnostic)
                    efficiency_coefficient =
                        if graph[asset].type in case.selected_assets || use_highest_resolution
                            1.0
                        else
                            if case.col_name == :incoming_flow
                                row.efficiency
                            else
                                # Divide by efficiency for outgoing flows
                                1.0 / row.efficiency
                            end
                        end
                    add_to_expression!(workspace[t], row.flow, resolution * efficiency_coefficient)
                end
            end
            # Sum the corresponding flows from the workspace
            for row in eachrow(sub_df)
                row[case.col_name] = agg(@view workspace[row.time_block])
            end
        end
    end
end

"""
    add_expression_terms_inter_rp_constraints!(df_inter,
                                               df_flows,
                                               df_map,
                                               graph,
                                               representative_periods,
                                               )

Computes the incoming and outgoing expressions per row of df_inter for the constraints
that are between (inter) the representative period.

This function is only used internally in the model.

"""
function add_expression_terms_inter_rp_constraints!(
    df_inter,
    df_flows,
    df_map,
    graph,
    representative_periods,
)
    df_inter[!, :incoming_flow] .= AffExpr(0.0)
    df_inter[!, :outgoing_flow] .= AffExpr(0.0)
    df_inter[!, :inflows_profile_aggregation] .= AffExpr(0.0)

    # Incoming, outgoing flows, and profile aggregation
    for row_inter in eachrow(df_inter)
        sub_df_map = filter(row -> row.period in row_inter.base_period_block, df_map)

        for row_map in eachrow(sub_df_map)
            sub_df_flows =
                filter(row -> row.to == row_inter.asset && row.rp == row_map.rep_period, df_flows)
            row_inter.incoming_flow +=
                dot(sub_df_flows.flow, sub_df_flows.efficiency) * row_map.weight
            sub_df_flows =
                filter(row -> row.from == row_inter.asset && row.rp == row_map.rep_period, df_flows)
            row_inter.outgoing_flow +=
                dot(sub_df_flows.flow, sub_df_flows.efficiency) * row_map.weight
            row_inter.inflows_profile_aggregation +=
                profile_aggregation(
                    sum,
                    graph[row_inter.asset].rep_periods_profiles,
                    ("inflows", row_map.rep_period),
                    representative_periods[row_map.rep_period].time_steps,
                    0.0,
                ) *
                graph[row_inter.asset].storage_inflows *
                row_map.weight
        end
    end
end

"""
    profile_aggregation(agg, profiles, key, time_block, default_value)

Aggregates the `profiles[key]` over the `time_block` using the `agg` function.
If the profile does not exist, uses `default_value` instead of **each** profile value.

`profiles` should be a dictionary of profiles, for instance `graph[a].profiles` or `graph[u, v].profiles`.
If `profiles[key]` exists, then this function computes the aggregation of `profiles[key]`
over the range `time_block` using the aggregator `agg`, i.e., `agg(profiles[key][time_block])`.
If `profiles[key]` does not exist, then this substitutes it by a vector of `default_value`s.
"""
function profile_aggregation(agg, profiles, key, time_block, default_value)
    if haskey(profiles, key)
        return agg(profiles[key][time_block])
    else
        return agg(Iterators.repeated(default_value, length(time_block)))
    end
end

"""
    create_model!(energy_problem; verbose = false)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    graph = energy_problem.graph
    representative_periods = energy_problem.representative_periods
    constraints_partitions = energy_problem.constraints_partitions
    base_periods = energy_problem.base_periods
    energy_problem.dataframes =
        construct_dataframes(graph, representative_periods, constraints_partitions, base_periods)
    energy_problem.model = create_model(
        graph,
        representative_periods,
        energy_problem.dataframes,
        base_periods;
        kwargs...,
    )
    energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
    energy_problem.solved = false
    energy_problem.objective_value = NaN
    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes, base_periods; write_lp_file = false)

Create the energy model given the `graph`, `representative_periods`, dictionary of `dataframes` (created by [`construct_dataframes`](@ref)), and base_periods.
"""
function create_model(
    graph,
    representative_periods,
    dataframes,
    base_periods;
    write_lp_file = false,
)

    ## Helper functions
    # Computes the duration of the `block` and multiply by the resolution of the
    # representative period `rp`.
    function duration(time_block, rp)
        return length(time_block) * representative_periods[rp].resolution
    end

    ## Sets unpacking
    A = labels(graph) |> collect
    F = edge_labels(graph) |> collect
    filter_assets(key, value) =
        filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) == value, A)
    filter_flows(key, value) = filter(f -> getfield(graph[f...], key) == value, F)

    Ac  = filter_assets(:type, "consumer")
    Ap  = filter_assets(:type, "producer")
    As  = filter_assets(:type, "storage")
    Ah  = filter_assets(:type, "hub")
    Acv = filter_assets(:type, "conversion")
    Ft  = filter_flows(:is_transport, true)

    # Create subsets of assets by investable
    Ai = filter_assets(:investable, true)
    Fi = filter_flows(:investable, true)

    # Maximum time step
    Tmax = maximum(last(rp.time_steps) for rp in representative_periods)
    expression_workspace = Vector{AffExpr}(undef, Tmax)

    # Unpacking dataframes
    df_flows = dataframes[:flows]

    df_storage_intra_rp_balance_grouped =
        groupby(dataframes[:lowest_storage_level_intra_rp], [:asset, :rp])
    df_storage_inter_rp_balance_grouped = groupby(dataframes[:storage_level_inter_rp], [:asset])

    ## Model
    model = Model()

    ## Variables
    flow =
        model[:flow] =
            df_flows.flow = [
                @variable(
                    model,
                    base_name = "flow[($(row.from), $(row.to)), $(row.rp), $(row.time_block)]"
                ) for row in eachrow(df_flows)
            ]
    @variable(model, 0 ≤ assets_investment[Ai])  #number of installed asset units [N]
    @variable(model, 0 ≤ flows_investment[Fi])
    storage_level_intra_rp =
        model[:storage_level_intra_rp] = [
            @variable(
                model,
                lower_bound = 0.0,
                base_name = "storage_level_intra_rp[$(row.asset),$(row.rp),$(row.time_block)]"
            ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
        ]
    storage_level_inter_rp =
        model[:storage_level_inter_rp] = [
            @variable(
                model,
                lower_bound = 0.0,
                base_name = "storage_level_inter_rp[$(row.asset),$(row.base_period_block)]"
            ) for row in eachrow(dataframes[:storage_level_inter_rp])
        ]
    ### Integer Investment Variables
    for a ∈ Ai
        if graph[a].investment_integer
            set_integer(assets_investment[a])
        end
    end

    for (u, v) ∈ Fi
        if graph[u, v].investment_integer
            set_integer(flows_investment[(u, v)])
        end
    end

    ## Expressions
    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        graph[a].energy_to_power_ratio * graph[a].capacity * assets_investment[a]
    )

    # Creating the incoming and outgoing flow expressions
    add_expression_terms_intra_rp_constraints!(
        dataframes[:lowest],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    add_expression_terms_intra_rp_constraints!(
        dataframes[:lowest_storage_level_intra_rp],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    add_expression_terms_intra_rp_constraints!(
        dataframes[:highest_in_out],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    add_expression_terms_intra_rp_constraints!(
        dataframes[:highest_in],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    add_expression_terms_intra_rp_constraints!(
        dataframes[:highest_out],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    add_expression_terms_inter_rp_constraints!(
        dataframes[:storage_level_inter_rp],
        df_flows,
        base_periods.rp_mapping_df,
        graph,
        representative_periods,
    )
    incoming_flow_lowest_resolution =
        model[:incoming_flow_lowest_resolution] = dataframes[:lowest].incoming_flow
    outgoing_flow_lowest_resolution =
        model[:outgoing_flow_lowest_resolution] = dataframes[:lowest].outgoing_flow
    incoming_flow_lowest_storage_resolution_intra_rp =
        model[:incoming_flow_lowest_storage_resolution_intra_rp] =
            dataframes[:lowest_storage_level_intra_rp].incoming_flow
    outgoing_flow_lowest_storage_resolution_intra_rp =
        model[:outgoing_flow_lowest_storage_resolution_intra_rp] =
            dataframes[:lowest_storage_level_intra_rp].outgoing_flow
    incoming_flow_highest_in_out_resolution =
        model[:incoming_flow_highest_in_out_resolution] = dataframes[:highest_in_out].incoming_flow
    outgoing_flow_highest_in_out_resolution =
        model[:outgoing_flow_highest_in_out_resolution] = dataframes[:highest_in_out].outgoing_flow
    incoming_flow_highest_in_resolution =
        model[:incoming_flow_highest_in_resolution] = dataframes[:highest_in].incoming_flow
    outgoing_flow_highest_out_resolution =
        model[:outgoing_flow_highest_out_resolution] = dataframes[:highest_out].outgoing_flow
    incoming_flow_storage_inter_rp_balance =
        model[:incoming_flow_storage_inter_rp_balance] =
            dataframes[:storage_level_inter_rp].incoming_flow
    outgoing_flow_storage_inter_rp_balance =
        model[:outgoing_flow_storage_inter_rp_balance] =
            dataframes[:storage_level_inter_rp].outgoing_flow
    # Below, we drop zero coefficients, but probably we don't have any
    # (if the implementation is correct)
    drop_zeros!.(incoming_flow_lowest_resolution)
    drop_zeros!.(outgoing_flow_lowest_resolution)
    drop_zeros!.(incoming_flow_lowest_storage_resolution_intra_rp)
    drop_zeros!.(outgoing_flow_lowest_storage_resolution_intra_rp)
    drop_zeros!.(incoming_flow_highest_in_out_resolution)
    drop_zeros!.(outgoing_flow_highest_in_out_resolution)
    drop_zeros!.(incoming_flow_highest_in_resolution)
    drop_zeros!.(outgoing_flow_highest_out_resolution)
    drop_zeros!.(incoming_flow_storage_inter_rp_balance)
    drop_zeros!.(outgoing_flow_storage_inter_rp_balance)

    ## Expressions for the objective function
    assets_investment_cost = @expression(
        model,
        sum(graph[a].investment_cost * graph[a].capacity * assets_investment[a] for a ∈ Ai)
    )

    flows_investment_cost = @expression(
        model,
        sum(
            graph[u, v].investment_cost * graph[u, v].capacity * flows_investment[(u, v)] for
            (u, v) ∈ Fi
        )
    )

    flows_variable_cost = @expression(
        model,
        sum(
            representative_periods[row.rp].weight *
            duration(row.time_block, row.rp) *
            graph[row.from, row.to].variable_cost *
            row.flow for row in eachrow(df_flows)
        )
    )

    ## Objective function
    @objective(model, Min, assets_investment_cost + flows_investment_cost + flows_variable_cost)

    ## Balance constraints (using the lowest resolution)
    # - consumer balance equation
    df = filter(row -> row.asset ∈ Ac, dataframes[:highest_in_out]; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] ==
            profile_aggregation(
                mean,
                graph[row.asset].rep_periods_profiles,
                ("demand", row.rp),
                row.time_block,
                1.0,
            ) * graph[row.asset].peak_demand,
            base_name = "consumer_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    # - intra representative period (rp) storage balance equation
    for ((a, rp), sub_df) ∈ pairs(df_storage_intra_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_intra_rp_balance_$(a)_$(rp)")] = [
            @constraint(
                model,
                storage_level_intra_rp[row.index] ==
                (
                    if k > 1
                        storage_level_intra_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level)
                                storage_level_intra_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level
                            end
                        )
                    end
                ) +
                profile_aggregation(
                    sum,
                    graph[a].rep_periods_profiles,
                    ("inflows", rp),
                    row.time_block,
                    0.0,
                ) * graph[a].storage_inflows +
                incoming_flow_lowest_storage_resolution_intra_rp[row.index] -
                outgoing_flow_lowest_storage_resolution_intra_rp[row.index],
                base_name = "storage_intra_rp_balance[$a,$rp,$(row.time_block)]"
            ) for (k, row) ∈ enumerate(eachrow(sub_df))
        ]
    end
    # - inter representative periods (rp) storage balance equation
    for ((a,), sub_df) ∈ pairs(df_storage_inter_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_inter_rp_balance_$(a)")] = [
            @constraint(
                model,
                storage_level_inter_rp[row.index] ==
                (
                    if k > 1
                        storage_level_inter_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level)
                                storage_level_inter_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level
                            end
                        )
                    end
                ) +
                row.inflows_profile_aggregation +
                incoming_flow_storage_inter_rp_balance[row.index] -
                outgoing_flow_storage_inter_rp_balance[row.index],
                base_name = "storage_inter_rp_balance[$a,$(row.base_period_block)]"
            ) for (k, row) ∈ enumerate(eachrow(sub_df))
        ]
    end

    # - hub balance equation
    df = filter(row -> row.asset ∈ Ah, dataframes[:highest_in_out]; view = true)
    model[:hub_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] ==
            outgoing_flow_highest_in_out_resolution[row.index],
            base_name = "hub_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    # - conversion balance equation
    df = filter(row -> row.asset ∈ Acv, dataframes[:lowest]; view = true)
    model[:conversion_balance] = [
        @constraint(
            model,
            incoming_flow_lowest_resolution[row.index] ==
            outgoing_flow_lowest_resolution[row.index],
            base_name = "conversion_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    assets_profile_times_capacity_in =
        model[:assets_profile_times_capacity_in] = [
            if row.asset ∈ Ai
                @expression(
                    model,
                    profile_aggregation(
                        mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rp),
                        row.time_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity +
                        graph[row.asset].capacity * assets_investment[row.asset]
                    )
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rp),
                        row.time_block,
                        1.0,
                    ) * graph[row.asset].initial_capacity
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    assets_profile_times_capacity_out =
        model[:assets_profile_times_capacity_out] = [
            if row.asset ∈ Ai
                @expression(
                    model,
                    profile_aggregation(
                        mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rp),
                        row.time_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity +
                        graph[row.asset].capacity * assets_investment[row.asset]
                    )
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rp),
                        row.time_block,
                        1.0,
                    ) * graph[row.asset].initial_capacity
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    ## Capacity limit constraints (using the highest resolution)
    # - maximum output flows limit
    model[:max_output_flows_limit] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out[row.index],
            base_name = "max_output_flows_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    # - maximum input flows limit
    model[:max_input_flows_limit] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in[row.index],
            base_name = "max_input_flows_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        incoming_flow_highest_in_resolution[row.index] != 0
    ]

    # - define lower bounds for flows that are not transport assets
    for row in eachrow(df_flows)
        if !graph[row.from, row.to].is_transport
            set_lower_bound(flow[row.index], 0.0)
        end
    end

    ## Expressions for transport flow constraints
    upper_bound_transport_flow = [
        if graph[row.from, row.to].investable
            @expression(
                model,
                profile_aggregation(
                    mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    ("availability", row.rp),
                    row.time_block,
                    1.0,
                ) * (
                    graph[row.from, row.to].initial_export_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                profile_aggregation(
                    mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    ("availability", row.rp),
                    row.time_block,
                    1.0,
                ) * graph[row.from, row.to].initial_export_capacity
            )
        end for row in eachrow(df_flows)
    ]

    lower_bound_transport_flow = [
        if graph[row.from, row.to].investable
            @expression(
                model,
                profile_aggregation(
                    mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    ("availability", row.rp),
                    row.time_block,
                    1.0,
                ) * (
                    graph[row.from, row.to].initial_import_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                profile_aggregation(
                    mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    ("availability", row.rp),
                    row.time_block,
                    1.0,
                ) * graph[row.from, row.to].initial_import_capacity
            )
        end for row in eachrow(df_flows)
    ]

    ## Constraints that define bounds for a transport flow Ft
    df = filter(row -> (row.from, row.to) ∈ Ft, df_flows)
    model[:max_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≤ upper_bound_transport_flow[row.index],
            base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    model[:min_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≥ -lower_bound_transport_flow[row.index],
            base_name = "min_transport_flow_limit[($(row.from),$(row.to)),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    ## Extra constraints for storage assets
    # - maximum storage level within (intra) a representative period
    model[:max_storage_level_intra_rp_limit] = [
        @constraint(
            model,
            storage_level_intra_rp[row.index] ≤
            profile_aggregation(
                mean,
                graph[row.asset].rep_periods_profiles,
                ("max-storage-level", row.rp),
                row.time_block,
                1.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "max_storage_level_intra_rp_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row ∈ eachrow(dataframes[:lowest_storage_level_intra_rp])
    ]

    # - minimum storage level within (intra) a representative period
    model[:min_storage_level_intra_rp_limit] = [
        @constraint(
            model,
            storage_level_intra_rp[row.index] ≥
            profile_aggregation(
                mean,
                graph[row.asset].rep_periods_profiles,
                ("min-storage-level", row.rp),
                row.time_block,
                0.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "min_storage_level_intra_rp_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row ∈ eachrow(dataframes[:lowest_storage_level_intra_rp])
    ]

    # - cycling condition for storage level within (intra) a representative period
    for ((a, _), sub_df) ∈ pairs(df_storage_intra_rp_balance_grouped)
        # Again, ordering is assume
        if !ismissing(graph[a].initial_storage_level)
            set_lower_bound(
                storage_level_intra_rp[last(sub_df.index)],
                graph[a].initial_storage_level,
            )
        end
    end

    # - maximum storage level between (inter) representative periods
    model[:max_storage_level_inter_rp_limit] = [
        @constraint(
            model,
            storage_level_inter_rp[row.index] ≤
            profile_aggregation(
                mean,
                graph[row.asset].base_periods_profiles,
                "max-storage-level",
                row.base_period_block,
                1.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "max_storage_level_inter_rp_limit[$(row.asset),$(row.base_period_block)]"
        ) for row ∈ eachrow(dataframes[:storage_level_inter_rp])
    ]

    # - minimum storage level between (inter) representative periods
    model[:min_storage_level_inter_rp_limit] = [
        @constraint(
            model,
            storage_level_inter_rp[row.index] ≥
            profile_aggregation(
                mean,
                graph[row.asset].base_periods_profiles,
                "min-storage-level",
                row.base_period_block,
                0.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "min_storage_level_inter_rp_limit[$(row.asset),$(row.base_period_block)]"
        ) for row ∈ eachrow(dataframes[:storage_level_inter_rp])
    ]

    # - cycling condition for storage between (inter) representative periods
    for ((a,), sub_df) ∈ pairs(df_storage_inter_rp_balance_grouped)
        # Again, ordering is assume
        if !ismissing(graph[a].initial_storage_level)
            set_lower_bound(
                storage_level_inter_rp[last(sub_df.index)],
                graph[a].initial_storage_level,
            )
        end
    end

    ## Extra constraints for investment limits
    # - maximum (i.e., potential) investment limit for assets
    for a ∈ Ai
        if graph[a].capacity > 0 && !ismissing(graph[a].investment_limit)
            set_upper_bound(assets_investment[a], graph[a].investment_limit / graph[a].capacity)
        end
    end

    # - maximum (i.e., potential) investment limit for flows
    for (u, v) ∈ Fi
        if graph[u, v].capacity > 0 && !ismissing(graph[u, v].investment_limit)
            set_upper_bound(
                flows_investment[(u, v)],
                graph[u, v].investment_limit / graph[u, v].capacity,
            )
        end
    end

    if write_lp_file
        write_to_file(model, "model.lp")
    end

    return model
end
