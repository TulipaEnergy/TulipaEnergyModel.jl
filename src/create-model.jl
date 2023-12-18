export create_model!, create_model

const TupleAssetRPTimeBlock = Tuple{String,Int,TimeBlock}
const TupleDurationFlowTimeBlock = Tuple{Float64,Tuple{String,String},TimeBlock}

function add_to_flow!(flow_sum_indices, graph, representative_periods, a, rp, P, f)
    search_start_index = 1
    flow_partitions = graph[f...].partitions[rp]
    num_flow_partitions = length(flow_partitions)
    for B ∈ P
        # Update search_start_index
        while last(flow_partitions[search_start_index]) < first(B)
            search_start_index += 1
            if search_start_index > num_flow_partitions
                break
            end
        end
        last_B = last(B)
        for j = search_start_index:num_flow_partitions
            B_flow = flow_partitions[j]
            d = length(B ∩ B_flow) * representative_periods[rp].resolution
            if d != 0
                push!(flow_sum_indices[a, rp, B], (d, f, B_flow))
            end
            if first(B_flow) > last_B
                break
            end
        end
    end
end

"""
    create_model!(energy_problem)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    graph = energy_problem.graph
    representative_periods = energy_problem.representative_periods
    constraints_partitions = energy_problem.constraints_partitions
    energy_problem.model =
        create_model(graph, representative_periods, constraints_partitions; kwargs...)
    return energy_problem
end

"""
    model = create_model(graph, representative_periods, constraints_partitions)

Create the energy model given the graph, representative_periods, and constraints_partitions.
"""
function create_model(graph, representative_periods, constraints_partitions; write_lp_file = false)

    ## Helper functions
    # Computes the duration of the `block` that is within the `period`, and
    # multiply by the resolution of the representative period `rp`.
    # It is equivalent to finding the indices of these values in the matrix.
    function duration(B1, B2, rp)
        return length(B1 ∩ B2) * representative_periods[rp].resolution
    end

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
    RP = 1:length(representative_periods)
    Pl = constraints_partitions[:lowest_resolution]
    Ph = constraints_partitions[:highest_resolution]

    ## Model
    model = Model()

    ## Variables
    @variable(model, flow[(u, v) ∈ F, rp ∈ RP, graph[u, v].partitions[rp]])
    @variable(model, 0 ≤ assets_investment[Ai])
    @variable(model, 0 ≤ flows_investment[Fi])
    @variable(model, 0 ≤ storage_level[a ∈ As, rp ∈ RP, Pl[(a, rp)]])

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
            representative_periods[rp].weight *
            duration(B_flow, rp) *
            graph[u, v].variable_cost *
            flow[(u, v), rp, B_flow] for (u, v) ∈ F, rp ∈ RP,
            B_flow ∈ graph[u, v].partitions[rp]
        )
    )

    ## Objective function
    @objective(model, Min, assets_investment_cost + flows_investment_cost + flows_variable_cost)

    flow_sum_indices_incoming_lowest =
        Dict{TupleAssetRPTimeBlock,Vector{TupleDurationFlowTimeBlock}}()
    flow_sum_indices_outgoing_lowest =
        Dict{TupleAssetRPTimeBlock,Vector{TupleDurationFlowTimeBlock}}()
    flow_sum_indices_incoming_highest =
        Dict{TupleAssetRPTimeBlock,Vector{TupleDurationFlowTimeBlock}}()
    flow_sum_indices_outgoing_highest =
        Dict{TupleAssetRPTimeBlock,Vector{TupleDurationFlowTimeBlock}}()
    for a ∈ A, rp ∈ RP
        for B ∈ Pl[(a, rp)]
            flow_sum_indices_incoming_lowest[a, rp, B] = TupleDurationFlowTimeBlock[]
            flow_sum_indices_outgoing_lowest[a, rp, B] = TupleDurationFlowTimeBlock[]
        end
        for B ∈ Ph[(a, rp)]
            flow_sum_indices_incoming_highest[a, rp, B] = TupleDurationFlowTimeBlock[]
            flow_sum_indices_outgoing_highest[a, rp, B] = TupleDurationFlowTimeBlock[]
        end

        for u ∈ inneighbor_labels(graph, a)
            add_to_flow!(
                flow_sum_indices_incoming_lowest,
                graph,
                representative_periods,
                a,
                rp,
                Pl[(a, rp)],
                (u, a),
            )
            add_to_flow!(
                flow_sum_indices_incoming_highest,
                graph,
                representative_periods,
                a,
                rp,
                Ph[(a, rp)],
                (u, a),
            )
        end

        for v ∈ outneighbor_labels(graph, a)
            add_to_flow!(
                flow_sum_indices_outgoing_lowest,
                graph,
                representative_periods,
                a,
                rp,
                Pl[(a, rp)],
                (a, v),
            )
            add_to_flow!(
                flow_sum_indices_outgoing_highest,
                graph,
                representative_periods,
                a,
                rp,
                Ph[(a, rp)],
                (a, v),
            )
        end
    end

    ## Expressions for balance constraints
    @expression(
        model,
        incoming_flow_lowest_resolution[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] for
            (d, f, B_flow) ∈ flow_sum_indices_incoming_lowest[(a, rp, B)]
        )
    )

    @expression(
        model,
        outgoing_flow_lowest_resolution[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] for
            (d, f, B_flow) ∈ flow_sum_indices_outgoing_lowest[(a, rp, B)]
        )
    )

    @expression(
        model,
        incoming_flow_lowest_resolution_w_efficiency[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] * graph[f...].efficiency for
            (d, f, B_flow) ∈ flow_sum_indices_incoming_lowest[(a, rp, B)]
        )
    )

    @expression(
        model,
        outgoing_flow_lowest_resolution_w_efficiency[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] / graph[f...].efficiency for
            (d, f, B_flow) ∈ flow_sum_indices_outgoing_lowest[(a, rp, B)]
        )
    )

    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        graph[a].energy_to_power_ratio * graph[a].capacity * assets_investment[a]
    )

    @expression(
        model,
        storage_inflows[a ∈ As, rp ∈ RP, T ∈ Pl[(a, rp)]],
        assets_profile_sum(a, rp, T, 0.0) *
        (graph[a].initial_storage_capacity + (a ∈ Ai ? energy_limit[a] : 0.0))
    )

    ## Balance constraints (using the lowest resolution)
    # - consumer balance equation
    @constraint(
        model,
        consumer_balance[a ∈ Ac, rp ∈ RP, B ∈ Pl[(a, rp)]],
        incoming_flow_lowest_resolution[(a, rp, B)] - outgoing_flow_lowest_resolution[(a, rp, B)] ==
        assets_profile_sum(a, rp, B, 1.0) * graph[a].peak_demand
    )

    # - storage balance equation
    @constraint(
        model,
        storage_balance[a ∈ As, rp ∈ RP, (k, B) ∈ enumerate(Pl[(a, rp)])],
        storage_level[a, rp, B] ==
        (
            if k > 1
                storage_level[a, rp, Pl[(a, rp)][k-1]]
            else
                (
                    if ismissing(graph[a].initial_storage_level)
                        storage_level[a, rp, Pl[(a, rp)][end]]
                    else
                        graph[a].initial_storage_level
                    end
                )
            end
        ) +
        storage_inflows[a, rp, B] +
        incoming_flow_lowest_resolution_w_efficiency[(a, rp, B)] -
        outgoing_flow_lowest_resolution_w_efficiency[(a, rp, B)]
    )

    # - hub balance equation
    @constraint(
        model,
        hub_balance[a ∈ Ah, rp ∈ RP, B ∈ Pl[(a, rp)]],
        incoming_flow_lowest_resolution[(a, rp, B)] == outgoing_flow_lowest_resolution[(a, rp, B)]
    )

    # - conversion balance equation
    @constraint(
        model,
        conversion_balance[a ∈ Acv, rp ∈ RP, B ∈ Pl[(a, rp)]],
        incoming_flow_lowest_resolution_w_efficiency[(a, rp, B)] ==
        outgoing_flow_lowest_resolution_w_efficiency[(a, rp, B)]
    )

    ## Expression for capacity limit constraints
    @expression(
        model,
        incoming_flow_highest_resolution[a ∈ A, rp ∈ RP, B ∈ Ph[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] for
            (d, f, B_flow) in flow_sum_indices_incoming_highest[a, rp, B]
        )
    )

    @expression(
        model,
        outgoing_flow_highest_resolution[a ∈ A, rp ∈ RP, B ∈ Ph[(a, rp)]],
        sum(
            d * flow[f, rp, B_flow] for
            (d, f, B_flow) in flow_sum_indices_outgoing_highest[a, rp, B]
        )
    )

    @expression(
        model,
        assets_profile_times_capacity[a ∈ A, rp ∈ RP, B ∈ Ph[(a, rp)]],
        assets_profile_sum(a, rp, B, 1.0) *
        (graph[a].initial_capacity + (a ∈ Ai ? (graph[a].capacity * assets_investment[a]) : 0.0))
    )

    ## Capacity limit constraints (using the highest resolution)
    # - maximum output flows limit
    @constraint(
        model,
        max_output_flows_limit[a ∈ Acv∪As∪Ap, rp ∈ RP, B ∈ Ph[(a, rp)]],
        outgoing_flow_highest_resolution[(a, rp, B)] ≤ assets_profile_times_capacity[a, rp, B]
    )

    # - maximum input flows limit
    @constraint(
        model,
        max_input_flows_limit[a ∈ As, rp ∈ RP, B ∈ Ph[(a, rp)]],
        incoming_flow_highest_resolution[(a, rp, B)] ≤ assets_profile_times_capacity[a, rp, B]
    )

    # - define lower bounds for flows that are not transport assets
    for f ∈ F, rp ∈ RP, B_flow ∈ graph[f...].partitions[rp]
        if f ∉ Ft
            set_lower_bound(flow[f, rp, B_flow], 0.0)
        end
    end

    ## Expressions for transport flow constraints
    @expression(
        model,
        upper_bound_transport_flow[(u, v) ∈ F, rp ∈ RP, B_flow ∈ graph[u, v].partitions[rp]],
        flows_profile_sum(u, v, rp, B_flow, 1.0) * (
            graph[u, v].initial_export_capacity +
            (graph[u, v].investable ? graph[u, v].capacity * flows_investment[(u, v)] : 0.0)
        )
    )

    @expression(
        model,
        lower_bound_transport_flow[(u, v) ∈ F, rp ∈ RP, B_flow ∈ graph[u, v].partitions[rp]],
        flows_profile_sum(u, v, rp, B_flow, 1.0) * (
            graph[u, v].initial_import_capacity +
            (graph[u, v].investable ? graph[u, v].capacity * flows_investment[(u, v)] : 0.0)
        )
    )

    ## Constraints that define bounds for a transport flow Ft
    @constraint(
        model,
        max_transport_flow_limit[f ∈ Ft, rp ∈ RP, B_flow ∈ graph[f...].partitions[rp]],
        duration(B_flow, rp) * flow[f, rp, B_flow] ≤ upper_bound_transport_flow[f, rp, B_flow]
    )

    @constraint(
        model,
        min_transport_flow_limit[f ∈ Ft, rp ∈ RP, B_flow ∈ graph[f...].partitions[rp]],
        duration(B_flow, rp) * flow[f, rp, B_flow] ≥ -lower_bound_transport_flow[f, rp, B_flow]
    )

    ## Extra constraints for storage assets
    # - maximum storage level limit
    @constraint(
        model,
        max_storage_level_limit[a ∈ As, rp ∈ RP, B ∈ Pl[(a, rp)]],
        storage_level[a, rp, B] ≤
        graph[a].initial_storage_capacity + (a ∈ Ai ? energy_limit[a] : 0.0)
    )

    # - cycling condition for storage level
    for a ∈ As, rp ∈ RP
        if !ismissing(graph[a].initial_storage_level)
            set_lower_bound(storage_level[a, rp, Pl[(a, rp)][end]], graph[a].initial_storage_level)
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
