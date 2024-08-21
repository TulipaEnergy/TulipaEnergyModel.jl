export solve_model!, solve_model

"""
    solution = solve_model!(energy_problem[, optimizer; parameters])

Solve the internal model of an `energy_problem`. The solution obtained by calling
[`solve_model`](@ref) is returned.
"""
function solve_model!(
    energy_problem::EnergyProblem,
    optimizer = HiGHS.Optimizer;
    parameters = default_parameters(optimizer),
)
    elapsed_time_solve_model = @elapsed begin
        model = energy_problem.model
        if model === nothing
            error("Model is not created, run create_model(energy_problem) first.")
        end

        energy_problem.solution =
            solve_model!(energy_problem.dataframes, model, optimizer; parameters = parameters)
        energy_problem.termination_status = JuMP.termination_status(model)
        if energy_problem.solution === nothing
            # Warning has been given at internal function
            return
        end
        energy_problem.solved = true
        energy_problem.objective_value = JuMP.objective_value(model)

        graph = energy_problem.graph
        for a in MetaGraphsNext.labels(graph)
            asset = graph[a]
            if asset.investable
                if asset.investment_integer
                    asset.investment = round(Int, energy_problem.solution.assets_investment[a])
                else
                    asset.investment = energy_problem.solution.assets_investment[a]
                end
                if asset.storage_method_energy
                    if asset.investment_integer_storage_energy
                        asset.investment_energy =
                            round(Int, energy_problem.solution.assets_investment_energy[a])
                    else
                        asset.investment_energy =
                            energy_problem.solution.assets_investment_energy[a]
                    end
                end
            end
        end

        for row in eachrow(energy_problem.dataframes[:lowest_storage_level_intra_rp])
            a, rp, timesteps_block, value =
                row.asset, row.rep_period, row.timesteps_block, row.solution
            graph[a].storage_level_intra_rp[(rp, timesteps_block)] = value
        end

        for row in eachrow(energy_problem.dataframes[:storage_level_inter_rp])
            a, pb, value = row.asset, row.periods_block, row.solution
            graph[a].storage_level_inter_rp[pb] = value
        end

        for row in eachrow(energy_problem.dataframes[:max_energy_inter_rp])
            a, pb, value = row.asset, row.periods_block, row.solution
            graph[a].max_energy_inter_rp[pb] = value
        end

        for row in eachrow(energy_problem.dataframes[:min_energy_inter_rp])
            a, pb, value = row.asset, row.periods_block, row.solution
            graph[a].min_energy_inter_rp[pb] = value
        end

        for (u, v) in MetaGraphsNext.edge_labels(graph)
            if graph[u, v].investable
                if graph[u, v].investment_integer
                    graph[u, v].investment =
                        round(Int, energy_problem.solution.flows_investment[(u, v)])
                else
                    graph[u, v].investment = energy_problem.solution.flows_investment[(u, v)]
                end
            end
        end

        for row in eachrow(energy_problem.dataframes[:flows])
            u, v, rp, timesteps_block, value =
                row.from, row.to, row.rep_period, row.timesteps_block, row.solution
            graph[u, v].flow[(rp, timesteps_block)] = value
        end
    end

    energy_problem.timings["solving the model"] = elapsed_time_solve_model

    return energy_problem.solution
end

"""
    solution = solve_model!(dataframes, model, ...)

Solves the JuMP `model`, returns the solution, and modifies `dataframes` to include the solution.
The modifications made to `dataframes` are:

- `df_flows.solution = solution.flow`
- `df_storage_level_intra_rp.solution = solution.storage_level_intra_rp`
- `df_storage_level_inter_rp.solution = solution.storage_level_inter_rp`
"""
function solve_model!(dataframes, model, args...; kwargs...)
    solution = solve_model(model, args...; kwargs...)
    if isnothing(solution)
        return nothing
    end

    dataframes[:flows].solution = solution.flow
    dataframes[:lowest_storage_level_intra_rp].solution = solution.storage_level_intra_rp
    dataframes[:storage_level_inter_rp].solution = solution.storage_level_inter_rp
    dataframes[:max_energy_inter_rp].solution = solution.max_energy_inter_rp
    dataframes[:min_energy_inter_rp].solution = solution.min_energy_inter_rp

    return solution
end

"""
    solution = solve_model(model[, optimizer; parameters])

Solve the JuMP model and return the solution. The `optimizer` argument should be an MILP solver from the JuMP
list of [supported solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
By default we use HiGHS.

The keyword argument `parameters` should be passed as a list of `key => value` pairs.
These can be created manually, obtained using [`default_parameters`](@ref), or read from a file
using [`read_parameters_from_file`](@ref).

The `solution` object is a mutable struct with the following fields:

  - `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
    To create a traditional array in the order given by the investable assets, one can run

    ```
    [solution.assets_investment[a] for a in labels(graph) if graph[a].investable]
    ```
    - `assets_investment_energy[a]`: The investment on energy component for each asset, indexed on the investable asset `a` with a `storage_method_energy` set to `true`.
    To create a traditional array in the order given by the investable assets, one can run

    ```
    [solution.assets_investment_energy[a] for a in labels(graph) if graph[a].investable && graph[a].storage_method_energy
    ```
  - `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
    To create a traditional array in the order given by the investable flows, one can run

    ```
    [solution.flows_investment[(u, v)] for (u, v) in edge_labels(graph) if graph[u, v].investable]
    ```
  - `storage_level_intra_rp[a, rp, timesteps_block]`: The storage level for the storage asset `a` for a representative period `rp`
    and a time block `timesteps_block`. The list of time blocks is defined by `constraints_partitions`, which was used
    to create the model.
    To create a vector with all values of `storage_level_intra_rp` for a given `a` and `rp`, one can run

    ```
    [solution.storage_level_intra_rp[a, rp, timesteps_block] for timesteps_block in constraints_partitions[:lowest_resolution][(a, rp)]]
    ```
- `storage_level_inter_rp[a, pb]`: The storage level for the storage asset `a` for a periods block `pb`.
    To create a vector with all values of `storage_level_inter_rp` for a given `a`, one can run

    ```
    [solution.storage_level_inter_rp[a, bp] for bp in graph[a].timeframe_partitions[a]]
    ```
- `flow[(u, v), rp, timesteps_block]`: The flow value for a given flow `(u, v)` at a given representative period
    `rp`, and time block `timesteps_block`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
    To create a vector with all values of `flow` for a given `(u, v)` and `rp`, one can run

    ```
    [solution.flow[(u, v), rp, timesteps_block] for timesteps_block in graph[u, v].partitions[rp]]
    ```
- `objective_value`: A Float64 with the objective value at the solution.
- `duals`: A NamedTuple containing the dual variables of selected constraints.

## Examples

```julia
parameters = Dict{String,Any}("presolve" => "on", "time_limit" => 60.0, "output_flag" => true)
solution = solve_model(model, HiGHS.Optimizer; parameters = parameters)
```
"""
function solve_model(
    model::JuMP.Model,
    optimizer = HiGHS.Optimizer;
    parameters = default_parameters(optimizer),
)
    # Set optimizer and its parameters
    JuMP.set_optimizer(model, optimizer)
    for (k, v) in parameters
        JuMP.set_attribute(model, k, v)
    end
    # Solve model
    @timeit to "total solver time" JuMP.optimize!(model)

    # Check solution status
    if JuMP.termination_status(model) != JuMP.OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    return Solution(
        Dict(
            (y, a) => JuMP.value(model[:assets_investment][y, a]) for
            y in model[:assets_investment].axes[1], a in model[:assets_investment].axes[2]
        ),
        Dict(
            (y, a) => JuMP.value(model[:assets_investment_energy][a]) for
            y in model[:assets_investment_energy].axes[1],
            a in model[:assets_investment_energy].axes[2]
        ),
        Dict(
            (y, uv) => JuMP.value(model[:flows_investment][uv]) for
            y in model[:flows_investment].axes[1], uv in model[:flows_investment].axes[2]
        ),
        JuMP.value.(model[:storage_level_intra_rp]),
        JuMP.value.(model[:storage_level_inter_rp]),
        JuMP.value.(model[:max_energy_inter_rp]),
        JuMP.value.(model[:min_energy_inter_rp]),
        JuMP.value.(model[:flow]),
        JuMP.objective_value(model),
        compute_dual_variables(model),
    )
end

"""
    compute_dual_variables(model)

Compute the dual variables for the given model.

If the model does not have dual variables, this function fixes the discrete variables, optimizes the model, and then computes the dual variables.

## Arguments
- `model`: The model for which to compute the dual variables.

## Returns
A named tuple containing the dual variables of selected constraints.
"""
function compute_dual_variables(model)
    try
        if !JuMP.has_duals(model)
            JuMP.fix_discrete_variables(model)
            JuMP.optimize!(model)
        end

        return Dict(
            :hub_balance => JuMP.dual.(model[:hub_balance]),
            :consumer_balance => JuMP.dual.(model[:consumer_balance]),
        )
    catch
        return nothing
    end
end
