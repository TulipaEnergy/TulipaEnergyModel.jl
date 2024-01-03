export solve_model!, solve_model, default_parameters

"""
    default_parameters(Val(optimizer_name_symbol))
    default_parameters(optimizer)
    default_parameters(optimizer_name_symbol)
    default_parameters(optimizer_name_string)

Returns the default parameters for a given JuMP optimizer.
Falls back to `Dict()` for undefined solvers.

## Arguments

There are four ways to use this function:

  - `Val(optimizer_name_symbol)`: This uses type dispatch with the special `Val` type.
    Just give the solver name as a Symbol (e.g., `Val(:HiGHS)`).
  - `optimizer`: The JuMP optimizer type (e.g., `HiGHS.Optimizer`).
  - `optimizer_name_symbol` or `optimizer_name_string`: Just give the name in Symbol
    or String format and we will convert to `Val`.

Using `Val` is necessary for the dispatch.
All other cases will convert the argument and call the `Val` version, which might lead to some type instability.

## Examples

```jldoctest
using HiGHS
default_parameters(HiGHS.Optimizer)

# output

Dict{String, Any} with 1 entry:
  "output_flag" => false
```

This also

```jldoctest
default_parameters(Val(:Cbc))

# output

Dict{String, Any} with 1 entry:
  "logLevel" => 0
```

```jldoctest
default_parameters(:Cbc) == default_parameters("Cbc") == default_parameters(Val(:Cbc))

# output

true
```
"""
default_parameters(::Any) = Dict{String,Any}()
default_parameters(::Val{:HiGHS}) = Dict{String,Any}("output_flag" => false)
default_parameters(::Val{:Cbc}) = Dict{String,Any}("logLevel" => 0)
default_parameters(::Val{:GLPK}) = Dict{String,Any}("msg_lev" => 0)

function default_parameters(::Type{T}) where {T<:MathOptInterface.AbstractOptimizer}
    solver_name = split(string(T), ".")[1]
    return default_parameters(Val(Symbol(solver_name)))
end

default_parameters(optimizer::Union{String,Symbol}) = default_parameters(Val(Symbol(optimizer)))

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

    solution = solve_model(model, optimizer; parameters = parameters)
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
    solution = solve_model(model[, optimizer; parameters])

Solve the JuMP model and return the solution. The `optimizer` argument should be a MILP solver from the JuMP
list of [supported solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
By default we use HiGHS.

The keyword argument `parameters` should be passed as a list of `key => value` pairs.

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
parameters = ["presolve" => "on", "time_limit" => 60.0, "output_flag" => true]
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
