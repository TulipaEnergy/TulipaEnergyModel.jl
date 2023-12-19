export solve_model!, solve_model

"""
    solution = solve_model!(energy_problem[, optimizer; parameters])

Solve the internal model of an energy_problem. The solution obtained by calling
[`solve_model`](@ref) is returned.
"""
function solve_model!(
    energy_problem::EnergyProblem,
    optimizer = HiGHS.Optimizer;
    parameters = default_parameters(optimizer),
)
    model = energy_problem.model
    if model === nothing
        error("Model is not created, run create_model(energy_problem) first.")
    end

    solution = solve_model!(energy_problem.dataframes, model, optimizer; parameters = parameters)
    energy_problem.termination_status = termination_status(model)
    if solution === nothing
        # Warning has been given at internal function
        return
    end
    energy_problem.solved = true
    energy_problem.objective_value = objective_value(model)

    graph = energy_problem.graph
    # rps = energy_problem.representative_periods
    for a in labels(graph)
        if graph[a].investable
            if graph[a].investment_integer
                graph[a].investment = round(Int, solution.assets_investment[a])
            else
                graph[a].investment = solution.assets_investment[a]
            end
        end
    end

    for row in eachrow(energy_problem.dataframes[:storage_level])
        a, rp, time_block, value = row.asset, row.rp, row.time_block, row.solution
        graph[a].storage_level[(rp, time_block)] = value
    end

    for (u, v) in edge_labels(graph)
        if graph[u, v].investable
            if graph[u, v].investment_integer
                graph[u, v].investment = round(Int, solution.flows_investment[(u, v)])
            else
                graph[u, v].investment = solution.flows_investment[(u, v)]
            end
        end
    end

    for row in eachrow(energy_problem.dataframes[:flows])
        u, v, rp, time_block, value = row.from, row.to, row.rp, row.time_block, row.solution
        graph[u, v].flow[(rp, time_block)] = value
    end

    return solution
end

"""
    solution = solve_model!(dataframes, model, ...)

Solves the JuMP `model` and return the solution, and modifies some `dataframes` to include the solution.
The modifications made to `dataframes` are:

- `df_flows.solution = solution.flow`
- `df_storage_level.solution = solution.storage_level`
"""
function solve_model!(dataframes, model, args...; kwargs...)
    solution = solve_model(model, args...; kwargs...)
    if isnothing(solution)
        return nothing
    end

    dataframes[:flows].solution = solution.flow
    dataframes[:storage_level].solution = solution.storage_level

    return solution
end

"""
    solution = solve_model(model[, optimizer; parameters])

Solve the JuMP model and return the solution. The `optimizer` argument should be a MILP solver from the JuMP
list of [supported solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
By default we use HiGHS.

The keyword argument `parameters` should be passed as a list of `key => value` pairs.
These can be created manually, obtained using [`default_parameters`](@ref), or read from a file
using [`read_parameters_from_file`](@ref).

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
    set_optimizer(model, optimizer)
    for (k, v) in parameters
        set_attribute(model, k, v)
    end
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
