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
    A = labels(graph) |> collect
    F = edge_labels(graph) |> collect
    RP = 1:length(representative_periods)
    Pl = constraints_partitions[:lowest_resolution]
    Ph = constraints_partitions[:highest_resolution]

    df_flows = DataFrame(
        (
            (
                (from = u, to = v, rp = rp, time_block = B, efficiency = graph[u, v].efficiency) for B ∈ graph[u, v].partitions[rp]
            ) for (u, v) ∈ F, rp ∈ RP
        ) |> Iterators.flatten,
    )
    df_flows.index = 1:size(df_flows, 1)

    # This construction should ensure the ordering of the time blocks for groups of (a, rp)
    df_constraints_lowest = DataFrame(
        (((asset = a, rp = rp, time_block = B) for B ∈ Pl[(a, rp)]) for a ∈ A, rp ∈ RP) |>
        Iterators.flatten,
    )
    df_constraints_lowest.index = 1:size(df_constraints_lowest, 1)

    df_constraints_highest = DataFrame(
        (((asset = a, rp = rp, time_block = B) for B ∈ Ph[(a, rp)]) for a ∈ A, rp ∈ RP) |>
        Iterators.flatten,
    )
    df_constraints_highest.index = 1:size(df_constraints_highest, 1)

    df_storage_level = rename(
        filter(row -> graph[row.asset].type == "storage", df_constraints_lowest),
        :index => :cons_index,
    )
    df_storage_level.index = 1:size(df_storage_level, 1)

    return Dict(
        :flows => df_flows,
        :cons_lowest => df_constraints_lowest,
        :cons_highest => df_constraints_highest,
        :storage_level => df_storage_level,
    )
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
    representative_periods;
    add_efficiency = true,
)
    if add_efficiency
        df_cons[!, :incoming_w_efficiency_term] .= AffExpr(0.0)
        df_cons[!, :outgoing_w_efficiency_term] .= AffExpr(0.0)
    else
        df_cons[!, :incoming_term] .= AffExpr(0.0)
        df_cons[!, :outgoing_term] .= AffExpr(0.0)
    end

    grouped_cons = groupby(df_cons, [:rp, :asset])

    # Incoming flows
    grouped_flows = groupby(df_flows, [:rp, :to])
    for ((rp, to), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_flows, (; rp, to))
            continue
        end
        resolution = representative_periods[rp].resolution
        for i in eachindex(workspace)
            workspace[i] = AffExpr(0.0)
        end
        # Store the corresponding flow in the workspace
        for row in eachrow(grouped_flows[(; rp, to)])
            for t ∈ row.time_block
                if row.efficiency != 0 || !add_efficiency
                    add_to_expression!(
                        workspace[t],
                        row.flow,
                        (resolution * (add_efficiency ? row.efficiency : 1.0)),
                    )
                end
            end
        end
        # Sum the corresponding flows from the workspace
        for row in eachrow(sub_df)
            if add_efficiency
                row.incoming_w_efficiency_term = sum(@view workspace[row.time_block])
            else
                row.incoming_term = sum(@view workspace[row.time_block])
            end
        end
    end

    # Outgoing flows
    grouped_flows = groupby(df_flows, [:rp, :from])
    for ((rp, from), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_flows, (; rp, from))
            continue
        end
        resolution = representative_periods[rp].resolution
        for i in eachindex(workspace)
            workspace[i] = AffExpr(0.0)
        end
        # Store the corresponding flow in the workspace
        for row in eachrow(grouped_flows[(; rp, from)])
            for t ∈ row.time_block
                if row.efficiency != 0 || !add_efficiency
                    add_to_expression!(
                        workspace[t],
                        row.flow,
                        (resolution / (add_efficiency ? row.efficiency : 1.0)),
                    )
                end
            end
        end
        # Sum the corresponding flows from the workspace
        for row in eachrow(sub_df)
            if add_efficiency
                row.outgoing_w_efficiency_term = sum(@view workspace[row.time_block])
            else
                row.outgoing_term = sum(@view workspace[row.time_block])
            end
        end
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
    energy_problem.dataframes =
        construct_dataframes(graph, representative_periods, constraints_partitions)
    energy_problem.model =
        create_model(graph, representative_periods, energy_problem.dataframes; kwargs...)
    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes)

Create the energy model given the graph, representative_periods, and dictionary of dataframes (created by [`construct_dataframes`](@ref)).
"""
function create_model(graph, representative_periods, dataframes; write_lp_file = false)

    ## Helper functions
    # Computes the duration of the `block` and multiply by the resolution of the
    # representative period `rp`.
    function duration(B, rp)
        return length(B) * representative_periods[rp].resolution
    end

    # Sums the profile of representative period rp over the time block B
    # Uses the default_value when that profile does not exist.
    function profile_sum(profiles, rp, B, default_value)
        if haskey(profiles, rp)
            return sum(profiles[rp][B])
        else
            return length(B) * default_value
        end
    end

    function assets_profile_sum(a, rp, B, default_value)
        return profile_sum(graph[a].profiles, rp, B, default_value)
    end

    # Same as above but for flow
    function flows_profile_sum(u, v, rp, B, default_value)
        return profile_sum(graph[u, v].profiles, rp, B, default_value)
    end

    ## Sets unpacking
    A = labels(graph) |> collect
    F = edge_labels(graph) |> collect
    filter_assets(key, value) = filter(a -> getfield(graph[a], key) == value, A)
    filter_flows(key, value) = filter(f -> getfield(graph[f...], key) == value, F)

    Ac = filter_assets(:type, "consumer")
    Ap = filter_assets(:type, "producer")
    Ai = filter_assets(:investable, true)
    As = filter_assets(:type, "storage")
    Ah = filter_assets(:type, "hub")
    Acv = filter_assets(:type, "conversion")
    Fi = filter_flows(:investable, true)
    Ft = filter_flows(:is_transport, true)

    Tmax = maximum(last(rp.time_steps) for rp in representative_periods)
    expression_workspace = Vector{AffExpr}(undef, Tmax)

    # Unpacking dataframes
    df_flows = dataframes[:flows]
    df_constraints_lowest = dataframes[:cons_lowest]
    df_constraints_highest = dataframes[:cons_highest]
    df_storage_level = dataframes[:storage_level]

    df_storage_level_grouped = groupby(df_storage_level, [:asset, :rp])

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
            @variable(model, base_name = "storage_level[$(row.asset),$(row.rp),$(row.time_block)]") for row in eachrow(df_storage_level)
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

    # TODO: Fix storage_level[As, RP, 0] = 0

    # Creating the incoming and outgoing flow expressions
    add_expression_terms!(
        df_constraints_lowest,
        df_flows,
        expression_workspace,
        representative_periods;
        add_efficiency = false,
    )
    add_expression_terms!(
        df_constraints_lowest,
        df_flows,
        expression_workspace,
        representative_periods;
        add_efficiency = true,
    )
    add_expression_terms!(
        df_constraints_highest,
        df_flows,
        expression_workspace,
        representative_periods;
        add_efficiency = false,
    )
    incoming_flow_lowest_resolution =
        model[:incoming_flow_lowest_resolution] = df_constraints_lowest.incoming_term
    outgoing_flow_lowest_resolution =
        model[:outgoing_flow_lowest_resolution] = df_constraints_lowest.outgoing_term
    incoming_flow_lowest_resolution_w_efficiency =
        model[:incoming_flow_lowest_resolution_w_efficiency] =
            df_constraints_lowest.incoming_w_efficiency_term
    outgoing_flow_lowest_resolution_w_efficiency =
        model[:outgoing_flow_lowest_resolution_w_efficiency] =
            df_constraints_lowest.outgoing_w_efficiency_term
    incoming_flow_highest_resolution =
        model[:incoming_flow_highest_resolution] = df_constraints_highest.incoming_term
    outgoing_flow_highest_resolution =
        model[:outgoing_flow_highest_resolution] = df_constraints_highest.outgoing_term
    drop_zeros!.(incoming_flow_lowest_resolution)
    drop_zeros!.(outgoing_flow_lowest_resolution)
    drop_zeros!.(incoming_flow_lowest_resolution_w_efficiency)
    drop_zeros!.(outgoing_flow_lowest_resolution_w_efficiency)
    drop_zeros!.(incoming_flow_highest_resolution)
    drop_zeros!.(outgoing_flow_highest_resolution)

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
    df = filter(row -> row.asset ∈ Ac, df_constraints_lowest; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_lowest_resolution[row.index] -
            outgoing_flow_lowest_resolution[row.index] ==
            assets_profile_sum(row.asset, row.rp, row.time_block, 1.0) *
            graph[row.asset].peak_demand,
            base_name = "consumer_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    # - storage balance equation
    for ((a, rp), sub_df) ∈ pairs(df_storage_level_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_balance_$(a)_$(rp)")] = [
            @constraint(
                model,
                storage_level[row.index] ==
                (
                    if k > 1
                        storage_level[row.index-1]
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
                assets_profile_sum(a, rp, row.time_block, 0.0) * (
                    graph[a].initial_storage_capacity +
                    (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
                ) +
                incoming_flow_lowest_resolution_w_efficiency[row.cons_index] -
                outgoing_flow_lowest_resolution_w_efficiency[row.cons_index],
                base_name = "storage_balance[$a,$rp,$(row.time_block)]"
            ) for (k, row) ∈ enumerate(eachrow(sub_df))
        ]
    end

    # - hub balance equation
    df = filter(row -> row.asset ∈ Ah, df_constraints_lowest; view = true)
    model[:hub_balance] = [
        @constraint(
            model,
            incoming_flow_lowest_resolution[row.index] ==
            outgoing_flow_lowest_resolution[row.index],
            base_name = "hub_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    # - conversion balance equation
    df = filter(row -> row.asset ∈ Acv, df_constraints_lowest; view = true)
    model[:conversion_balance] = [
        @constraint(
            model,
            incoming_flow_lowest_resolution_w_efficiency[row.index] ==
            outgoing_flow_lowest_resolution_w_efficiency[row.index],
            base_name = "conversion_balance[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    assets_profile_times_capacity =
        model[:assets_profile_times_capacity] = [
            if row.asset ∈ Ai
                @expression(
                    model,
                    assets_profile_sum(row.asset, row.rp, row.time_block, 1.0) * (
                        graph[row.asset].initial_capacity +
                        graph[row.asset].capacity * assets_investment[row.asset]
                    )
                )
            else
                @expression(
                    model,
                    assets_profile_sum(row.asset, row.rp, row.time_block, 1.0) *
                    graph[row.asset].initial_capacity
                )
            end for row in eachrow(df_constraints_highest)
        ]

    ## Capacity limit constraints (using the highest resolution)
    # - maximum output flows limit
    df = filter(
        row -> row.asset ∈ Acv || row.asset ∈ As || row.asset ∈ Ap,
        df_constraints_highest;
        view = true,
    )
    model[:max_output_flows_limit] = [
        @constraint(
            model,
            outgoing_flow_highest_resolution[row.index] ≤ assets_profile_times_capacity[row.index],
            base_name = "max_output_flows_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df) if outgoing_flow_highest_resolution[row.index] != 0
    ]

    # - maximum input flows limit
    df = filter(row -> row.asset ∈ As, df_constraints_highest; view = true)
    model[:max_input_flows_limit] = [
        @constraint(
            model,
            incoming_flow_highest_resolution[row.index] ≤ assets_profile_times_capacity[row.index],
            base_name = "max_input_flows_limit[$(row.asset),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
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
                flows_profile_sum(row.from, row.to, row.rp, row.time_block, 1.0) * (
                    graph[row.from, row.to].initial_export_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                flows_profile_sum(row.from, row.to, row.rp, row.time_block, 1.0) *
                graph[row.from, row.to].initial_export_capacity
            )
        end for row in eachrow(df_flows)
    ]

    lower_bound_transport_flow = [
        if graph[row.from, row.to].investable
            @expression(
                model,
                flows_profile_sum(row.from, row.to, row.rp, row.time_block, 1.0) * (
                    graph[row.from, row.to].initial_import_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                flows_profile_sum(row.from, row.to, row.rp, row.time_block, 1.0) *
                graph[row.from, row.to].initial_import_capacity
            )
        end for row in eachrow(df_flows)
    ]

    ## Constraints that define bounds for a transport flow Ft
    df = filter(row -> (row.from, row.to) ∈ Ft, df_flows)
    model[:max_transport_flow_limit] = [
        @constraint(
            model,
            duration(row.time_block, row.rp) * flow[row.index] ≤
            upper_bound_transport_flow[row.index],
            base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.rp),$(row.time_block)]"
        ) for row in eachrow(df)
    ]

    model[:min_transport_flow_limit] = [
        @constraint(
            model,
            duration(row.time_block, row.rp) * flow[row.index] ≥
            -lower_bound_transport_flow[row.index],
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
            (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
        ) for row ∈ eachrow(df_storage_level)
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
