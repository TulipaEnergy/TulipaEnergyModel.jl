export create_model!, create_model, construct_dataframes

"""
    dataframes = construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,
    )

Computes the data frames used to linearize the variables and constraints. These are used
internally in the model only.
"""
function construct_dataframes(graph, representative_periods, constraints_partitions)
    F = edge_labels(graph) |> collect
    RP = 1:length(representative_periods)

    # Output object
    dataframes = Dict{Symbol,DataFrame}()

    # DataFrame to store the flow variables
    dataframes[:flows] = DataFrame(
        (
            (
                (from = u, to = v, rp = rp, time_block = B, efficiency = graph[u, v].efficiency) for B ∈ graph[u, v].partitions[rp]
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

    return dataframes
end

"""
    add_expression_terms!(df_cons, df_flows, workspace, representative_periods; add_efficiency)

Computes the incoming and outgoing expressions per row of df_cons. This function
is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_terms!(
    df_cons,
    df_flows,
    workspace,
    representative_periods,
    graph;
    use_highest_resolution = true,
    multiply_by_duration = true,
)
    if !use_highest_resolution
        df_cons[!, :incoming_flow_lowest] .= AffExpr(0.0)
        df_cons[!, :outgoing_flow_lowest] .= AffExpr(0.0)
    else
        df_cons[!, :incoming_flow_highest] .= AffExpr(0.0)
        df_cons[!, :outgoing_flow_highest] .= AffExpr(0.0)
    end

    # Aggregating function: If the duration should NOT be taken into account, we have to compute unique appearances of the flows.
    # Otherwise, just use the sum
    agg = multiply_by_duration ? v -> sum(v) : v -> sum(unique(v))
    grouped_cons = groupby(df_cons, [:rp, :asset])

    # Incoming flows
    grouped_flows = groupby(df_flows, [:rp, :to])
    for ((rp, to), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_flows, (; rp, to))
            continue
        end
        resolution = multiply_by_duration ? representative_periods[rp].resolution : 1.0
        for i in eachindex(workspace)
            workspace[i] = AffExpr(0.0)
        end
        # Store the corresponding flow in the workspace
        for row in eachrow(grouped_flows[(; rp, to)])
            for t ∈ row.time_block
                # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                # And when you want the highest resolution (which is asset type-agnostic)
                selected_assets = ["hub", "consumer"]
                flag = graph[row.to].type in selected_assets || use_highest_resolution
                add_to_expression!(
                    workspace[t],
                    row.flow,
                    (resolution * (flag ? 1.0 : row.efficiency)),
                )
            end
        end
        # Sum the corresponding flows from the workspace
        for row in eachrow(sub_df)
            if !use_highest_resolution
                row.incoming_flow_lowest = agg(@view workspace[row.time_block])
            else
                row.incoming_flow_highest = agg(@view workspace[row.time_block])
            end
        end
    end

    # Outgoing flows
    grouped_flows = groupby(df_flows, [:rp, :from])
    for ((rp, from), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_flows, (; rp, from))
            continue
        end
        resolution = multiply_by_duration ? representative_periods[rp].resolution : 1.0
        for i in eachindex(workspace)
            workspace[i] = AffExpr(0.0)
        end
        # Store the corresponding flow in the workspace
        for row in eachrow(grouped_flows[(; rp, from)])
            for t ∈ row.time_block
                # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                # And when you want the highest resolution (which is asset type-agnostic)
                selected_assets = ["hub", "consumer", "producer"]
                flag = graph[row.from].type in selected_assets || use_highest_resolution
                add_to_expression!(
                    workspace[t],
                    row.flow,
                    (resolution / (flag ? 1.0 : row.efficiency)),
                )
            end
        end
        # Sum the corresponding flows from the workspace
        for row in eachrow(sub_df)
            if !use_highest_resolution
                row.outgoing_flow_lowest = agg(@view workspace[row.time_block])
            else
                row.outgoing_flow_highest = agg(@view workspace[row.time_block])
            end
        end
    end
end

"""
    profile_aggregation(agg, profiles, rp, time_block, default_value)

Aggregates the `profiles[rp]` over the `time_block` using the `agg` function.
If the profile does not exist, uses `default_value` instead of **each** profile value.

`profiles` should be a dictionary of profiles, for instance `graph[a].profiles` or `graph[u, v].profiles`.
If `profiles[rp]` exists, then this function computes the aggregation of `profiles[rp]`
over the range `time_block` using the aggregator `agg`, i.e., `agg(profiles[rp][time_block])`.
If `profiles[rp]` does not exist, then this substitutes it by a vector of `default_value`s.
"""
function profile_aggregation(agg, profiles, rp, B, default_value)
    if haskey(profiles, rp)
        return agg(profiles[rp][B])
    else
        return agg(Iterators.repeated(default_value, length(B)))
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
        construct_dataframes(graph, representative_periods, constraints_partitions)
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
    function duration(B, rp)
        return length(B) * representative_periods[rp].resolution
    end

    ## Sets unpacking
    P = 1:base_periods.num_base_periods
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

    # Create subsets of storage assets by storage type
    As_long  = intersect(As, filter_assets(:storage_type, "long"))
    As_short = setdiff(As, As_long) # if not long then it is short by default

    # Maximum time step
    Tmax = maximum(last(rp.time_steps) for rp in representative_periods)
    expression_workspace = Vector{AffExpr}(undef, Tmax)

    # Unpacking dataframes
    df_flows = dataframes[:flows]

    df_storage_level_grouped = groupby(dataframes[:lowest_storage_level], [:asset, :rp])

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
    storage_level =
        model[:storage_level] = [
            @variable(model, base_name = "storage_level[$(row.asset),$(row.rp),$(row.time_block)]") for row in eachrow(dataframes[:lowest_storage_level])
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

    # Creating the incoming and outgoing flow expressions
    add_expression_terms!(
        dataframes[:lowest],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    add_expression_terms!(
        dataframes[:lowest_storage_level],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    add_expression_terms!(
        dataframes[:highest_in_out],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    add_expression_terms!(
        dataframes[:highest_in],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    add_expression_terms!(
        dataframes[:highest_out],
        df_flows,
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    incoming_flow_lowest_resolution =
        model[:incoming_flow_lowest_resolution] = dataframes[:lowest].incoming_flow_lowest
    outgoing_flow_lowest_resolution =
        model[:outgoing_flow_lowest_resolution] = dataframes[:lowest].outgoing_flow_lowest
    incoming_flow_lowest_storage_resolution =
        model[:incoming_flow_lowest_storage_resolution] =
            dataframes[:lowest_storage_level].incoming_flow_lowest
    outgoing_flow_lowest_storage_resolution =
        model[:outgoing_flow_lowest_storage_resolution] =
            dataframes[:lowest_storage_level].outgoing_flow_lowest
    incoming_flow_highest_in_out_resolution =
        model[:incoming_flow_highest_in_out_resolution] =
            dataframes[:highest_in_out].incoming_flow_highest
    outgoing_flow_highest_in_out_resolution =
        model[:outgoing_flow_highest_in_out_resolution] =
            dataframes[:highest_in_out].outgoing_flow_highest
    incoming_flow_highest_in_resolution =
        model[:incoming_flow_highest_in_resolution] = dataframes[:highest_in].incoming_flow_highest
    outgoing_flow_highest_out_resolution =
        model[:outgoing_flow_highest_out_resolution] =
            dataframes[:highest_out].outgoing_flow_highest
    # Below, we drop zero coefficients, but probably we don't have any
    # (if the implementation is correct)
    drop_zeros!.(incoming_flow_lowest_resolution)
    drop_zeros!.(outgoing_flow_lowest_resolution)
    drop_zeros!.(incoming_flow_lowest_storage_resolution)
    drop_zeros!.(outgoing_flow_lowest_storage_resolution)
    drop_zeros!.(incoming_flow_highest_in_out_resolution)
    drop_zeros!.(outgoing_flow_highest_in_out_resolution)
    drop_zeros!.(incoming_flow_highest_in_resolution)
    drop_zeros!.(outgoing_flow_highest_out_resolution)

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

    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        graph[a].energy_to_power_ratio * graph[a].capacity * assets_investment[a]
    )

    ## Balance constraints (using the lowest resolution)
    # - consumer balance equation
    df = filter(row -> row.asset ∈ Ac, dataframes[:highest_in_out]; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] ==
            profile_aggregation(mean, graph[row.asset].profiles, row.rp, row.time_block, 1.0) *
            graph[row.asset].peak_demand,
            base_name = "consumer_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    # - storage balance equation for short-term storage
    for ((a, rp), sub_df) ∈ pairs(df_storage_level_grouped)
        if !(a in As_short)
            continue
        end
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_balance_$(a)_$(rp)")] = [
            @constraint(
                model,
                storage_level[row.index] ==
                (
                    if k > 1
                        storage_level[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level)
                                storage_level[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level
                            end
                        )
                    end
                ) +
                profile_aggregation(sum, graph[a].profiles, rp, row.time_block, 0.0) * (
                    graph[a].initial_storage_capacity +
                    (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
                ) +
                incoming_flow_lowest_storage_resolution[row.index] -
                outgoing_flow_lowest_storage_resolution[row.index],
                base_name = "storage_balance[$a,$rp,$(row.time_block)]"
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
                        graph[row.asset].profiles,
                        row.rp,
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
                        graph[row.asset].profiles,
                        row.rp,
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
                        graph[row.asset].profiles,
                        row.rp,
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
                        graph[row.asset].profiles,
                        row.rp,
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
                    graph[row.from, row.to].profiles,
                    row.rp,
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
                    graph[row.from, row.to].profiles,
                    row.rp,
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
                    graph[row.from, row.to].profiles,
                    row.rp,
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
                    graph[row.from, row.to].profiles,
                    row.rp,
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
    # - maximum storage level limit
    model[:max_storage_level_limit] = [
        @constraint(
            model,
            storage_level[row.index] ≤
            graph[row.asset].initial_storage_capacity +
            (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0),
            base_name = "max_storage_level_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row ∈ eachrow(dataframes[:lowest_storage_level])
    ]

    # - cycling condition for storage level
    for ((a, _), sub_df) ∈ pairs(df_storage_level_grouped)
        # Again, ordering is assume
        if !ismissing(graph[a].initial_storage_level)
            set_lower_bound(storage_level[last(sub_df.index)], graph[a].initial_storage_level)
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
