export solve_model!, solve_model, save_solution!

"""
    solve_model!(energy_problem::EnergyProblem)

Solve the internal model of an `energy_problem`.
"""
function solve_model!(energy_problem::EnergyProblem)
    model = energy_problem.model
    if model === nothing
        error("Model is not created, run create_model(energy_problem) first.")
    end

    solve_model(model)
    energy_problem.termination_status = JuMP.termination_status(model)
    if !JuMP.is_solved_and_feasible(model)
        # Warning has been given at internal function
        return
    end
    energy_problem.solved = true
    energy_problem.objective_value = JuMP.objective_value(model)
    return
end

"""
    solve_model(model::JuMP.Model)

Solve the JuMP model.
"""
function solve_model(model::JuMP.Model)

    # Solve model
    @timeit to "total solver time" JuMP.optimize!(model)

    # Check solution status
    if JuMP.termination_status(model) != JuMP.OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    return
end

"""
    save_solution!(energy_problem::EnergyProblem; compute_duals = true)
"""
function save_solution!(energy_problem::EnergyProblem; compute_duals = true)
    return save_solution!(
        energy_problem.db_connection,
        energy_problem.model,
        energy_problem.variables,
        energy_problem.constraints;
        compute_duals,
    )
end

"""
    save_solution!(connection, model, variables, constraints; compute_duals = true)

Saves the primal and dual variables values, in the following way:

- For each variable in `variables`, get the solution value and save it in a
column named `solution` in the corresponding dataset.
- For each constraint in `constraints`, get the dual of each attached
constraint listed in `constraint.constraint_names` and save it to the dictionary
`constraint.duals` with the key given by the name.

Notice that the duals are only computed if `compute_duals` is true.
"""
function save_solution!(connection, model, variables, constraints; compute_duals = true)
    # Check if it's solved
    if !JuMP.is_solved_and_feasible(model)
        @error(
            "The model has a termination status: $(string(JuMP.termination_status(model))), with primal status $(string(JuMP.primal_status(model))), and dual status $(string(JuMP.dual_status(model)))"
        )
        return
    end

    # Get variable values and save to corresponding table
    for (name, var) in variables
        if length(var.container) == 0
            continue
        end

        # Create a named tuple structure (row table compliant) to hold the solution (which follows the row format)
        # Note: This allocates memory, but I don't think there is a way to avoid it
        tmp_table = ((id = i, value = JuMP.value(v)) for (i, v) in enumerate(var.container))

        # Create a temporary DuckDB table for this table
        DuckDB.register_table(connection, tmp_table, "t_var_solution_$name")

        # Update the column values
        DuckDB.execute(
            connection,
            "UPDATE $(var.table_name)
            SET solution = sol.value
            FROM t_var_solution_$name AS sol
            WHERE $(var.table_name).id = sol.id
            ",
        )
    end

    if compute_duals
        # Compute the dual variables
        @timeit to "compute_dual_variables" compute_dual_variables!(model)

        for (name, cons) in constraints
            if cons.num_rows == 0
                continue
            elseif length(cons.constraint_names) == 0
                @warn "Constraint $name has no attached constraints!"
                continue
            end

            set_query_args = String[]

            # Save dual variables for each constraint attached to cons
            for cons_name in cons.constraint_names
                col_name = "dual_$cons_name"
                cons.duals[cons_name] = JuMP.dual.(model[cons_name])
                push!(set_query_args, "$col_name = cons.$cons_name")

                DuckDB.execute(
                    connection,
                    "ALTER TABLE $(cons.table_name) ADD COLUMN IF NOT EXISTS $col_name FLOAT8",
                )
            end

            # Create
            tmp_table = ((id = i, (k => v[i] for (k, v) in cons.duals)...) for i in 1:cons.num_rows)

            duals_table_name = "t_duals_$name"

            DuckDB.register_table(connection, tmp_table, duals_table_name)

            set_query = join(set_query_args, ", ")

            DuckDB.execute(
                connection,
                "UPDATE $(cons.table_name)
                SET $set_query
                FROM $duals_table_name AS cons
                WHERE $(cons.table_name).id = cons.id
                ",
            )
        end
    end

    return
end

"""
    compute_dual_variables!(model)

Compute the dual variables for the given model.

If the model does not have dual variables, this function fixes the discrete variables, optimizes the model, and then computes the dual variables.

## Arguments
- `model`: The model for which to compute the dual variables.

## Returns
A named tuple containing the dual variables of selected constraints.
"""
function compute_dual_variables!(model)
    try
        if !JuMP.has_duals(model)
            JuMP.fix_discrete_variables(model)
            JuMP.optimize!(model)
        end

        return nothing
    catch
        return nothing
    end
end
