export create_model!, solve_model!, create_model, solve_model

"""
    create_model!(energy_problem; verbose = false)

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
    model = create_model(graph, representative_periods)

Create the energy model given the graph and representative_periods.
"""
function create_model(
    graph,
    representative_periods,
    constraints_partitions;
    verbose = false,
    write_lp_file = false,
)

    ## Helper functions
    # Computes the duration of the `block` that is within the `period`, and
    # multiply by the resolution of the representative period `rp`.
    # It is equivalent to finding the indexes of these values in the matrix.
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
    A = labels(graph)
    F = edge_labels(graph)
    filter_assets(key, value) = Iterators.filter(a -> getfield(graph[a], key) == value, A)
    filter_flows(key, value) = Iterators.filter(f -> getfield(graph[f...], key) == value, F)

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
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "output_flag", verbose)

    ## Variables
    @variable(model, flow[(u, v) ∈ F, rp ∈ RP, graph[u, v].partitions[rp]])
    @variable(model, 0 ≤ assets_investment[Ai], Int)  #number of installed asset units [N]
    @variable(model, 0 ≤ flows_investment[Fi], Int)
    @variable(model, 0 ≤ storage_level[a ∈ As, rp ∈ RP, Pl[(a, rp)]])

    # TODO: Fix storage_level[As, RP, 0] = 0

    ## Expressions for the objective function
    assets_investment_cost = @expression(
        model,
        sum(graph[a].investment_cost * graph[a].capacity * assets_investment[a] for a ∈ Ai)
    )

    flows_investment_cost = @expression(
        model,
        sum(
            graph[u, v].investment_cost * graph[u, v].unit_capacity * flows_investment[(u, v)]
            for (u, v) ∈ Fi
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

    ## Expressions for balance constraints
    @expression(
        model,
        incoming_flow_lowest_resolution[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[(u, a), rp, B_flow] for
            u in inneighbor_labels(graph, a), B_flow ∈ graph[u, a].partitions[rp] if
            B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )

    @expression(
        model,
        outgoing_flow_lowest_resolution[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[(a, v), rp, B_flow] for
            v in outneighbor_labels(graph, a), B_flow ∈ graph[a, v].partitions[rp] if
            B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )

    @expression(
        model,
        incoming_flow_lowest_resolution_w_efficiency[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[(u, a), rp, B_flow] * graph[u, a].efficiency for
            u in inneighbor_labels(graph, a), B_flow ∈ graph[u, a].partitions[rp] if
            B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )
    @expression(
        model,
        outgoing_flow_lowest_resolution_w_efficiency[a ∈ A, rp ∈ RP, B ∈ Pl[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[(a, v), rp, B_flow] / graph[a, v].efficiency for
            v in outneighbor_labels(graph, a), B_flow ∈ graph[a, v].partitions[rp] if
            B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
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
        (k > 1 ? storage_level[a, rp, Pl[(a, rp)][k-1]] : graph[a].initial_storage_level) +
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
            duration(B, B_flow, rp) * flow[(u, a), rp, B_flow] for u in inneighbor_labels(graph, a),
            B_flow ∈ graph[u, a].partitions[rp]
        )
    )

    @expression(
        model,
        outgoing_flow_highest_resolution[a ∈ A, rp ∈ RP, B ∈ Ph[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[(a, v), rp, B_flow] for
            v in outneighbor_labels(graph, a), B_flow ∈ graph[a, v].partitions[rp]
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
            graph[u, v].initial_capacity +
            (graph[u, v].investable ? graph[u, v].export_capacity * flows_investment[(u, v)] : 0.0)
        )
    )

    @expression(
        model,
        lower_bound_transport_flow[(u, v) ∈ F, rp ∈ RP, B_flow ∈ graph[u, v].partitions[rp]],
        flows_profile_sum(u, v, rp, B_flow, 1.0) * (
            graph[u, v].initial_capacity +
            (graph[u, v].investable ? graph[u, v].import_capacity * flows_investment[(u, v)] : 0.0)
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
        set_lower_bound(storage_level[a, rp, Pl[(a, rp)][end]], graph[a].initial_storage_level)
    end

    ## Expressions for the extra constraints of investment limits
    @expression(
        model,
        flow_max_capacity[(u, v) ∈ Fi],
        max(graph[u, v].export_capacity, graph[u, v].import_capacity)
    )

    ## Extra constraints for investment limits
    # - maximum (i.e., potential) investment limit for assets
    for a ∈ Ai
        if graph[a].capacity > 0 && !ismissing(graph[a].investment_limit)
            set_upper_bound(assets_investment[a], graph[a].investment_limit / graph[a].capacity)
        end
    end

    # - maximum (i.e., potential) investment limit for flows
    for (u, v) ∈ Fi
        if flow_max_capacity[(u, v)] > 0 && !ismissing(graph[u, v].investment_limit)
            set_upper_bound(
                flows_investment[(u, v)],
                graph[u, v].investment_limit / flow_max_capacity[(u, v)],
            )
        end
    end

    if write_lp_file
        write_to_file(model, "model.lp")
    end

    return model
end

"""
    solution = solve_model!(energy_problem)

Solve the internal model of an energy_problem. The solution obtained by calling
[`solve_model`](@ref) is returned.
"""
function solve_model!(energy_problem::EnergyProblem)
    model = energy_problem.model
    if model === nothing
        error("Model is not created, run create_model(energy_problem) first.")
    end

    solution = solve_model(model)
    energy_problem.termination_status = termination_status(model)
    if solution === nothing
        # Warning has been given at internal function
        return
    end
    energy_problem.solved = true
    energy_problem.objective_value = objective_value(model)

    graph = energy_problem.graph
    rps = energy_problem.representative_periods
    for a in labels(graph)
        if graph[a].investable
            graph[a].investment = round(Int, solution.assets_investment[a])
        end
        if graph[a].type == "storage"
            for rp_id = 1:length(rps),
                I in energy_problem.constraints_partitions[:lowest_resolution][(a, rp_id)]

                graph[a].storage_level[(rp_id, I)] = solution.storage_level[(a, rp_id, I)]
            end
        end
    end
    for (u, v) in edge_labels(graph)
        if graph[u, v].investable
            graph[u, v].investment = round(Int, solution.flows_investment[(u, v)])
        end
        for rp_id = 1:length(rps), I in graph[u, v].partitions[rp_id]
            graph[u, v].flow[(rp_id, I)] = solution.flow[((u, v), rp_id, I)]
        end
    end

    return solution
end

"""
    solution = solve_model(model)

Solve the JuMP model and return the solution.

The `solution` object is a NamedTuple with the following fields:

  - `objective_value`: A Float64 with the objective value at the solution.

  - `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
    To create a traditional array in the order given by the investable assets, one can run

    ```
    [solution.assets_investment[a] for a in labels(graph) if graph[a].investable]
    ```
  - `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
    To create a traditional array in the order given by the investable flows, one can run

    ```
    [solution.flows_investment[(u, v)] for (u, v) in edge_labels(graph) if graph[u, v].investable]
    ```
  - `flow[(u, v), rp, B]`: The flow value for a given flow `(u, v)` at a given representative period
    `rp`, and time block `B`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
    To create a vector with all values of `flow` for a given `(u, v)` and `rp`, one can run

    ```
    [solution.flow[(u, v), rp, B] for B in graph[u, v].partitions[rp]]
    ```
  - `storage_level[a, rp, B]`: The storage level for the storage asset `a` for a representative period `rp`
    and a time block `B`. The list of time blocks is defined by `constraints_partitions`, which was used
    to create the model.
    To create a vector with the all values of `storage_level` for a given `a` and `rp`, one can run

    ```
    [solution.storage_level[a, rp, B] for B in constraints_partitions[:lowest_resolution][(a, rp)]]
    ```
"""
function solve_model(model::JuMP.Model)
    # Solve model
    optimize!(model)

    # Check solution status
    if termination_status(model) != OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    return (
        objective_value = objective_value(model),
        assets_investment = value.(model[:assets_investment]),
        flow = value.(model[:flow]),
        flows_investment = value.(model[:flows_investment]),
        storage_level = value.(model[:storage_level]),
    )
end
