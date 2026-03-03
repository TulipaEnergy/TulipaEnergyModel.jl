export add_start_up_upper_bound_constraints!

"""
    add_start_up_upper_bound_constraints!(model, constraints)

    Adds the start up upper bound constraints to the model.
"""
function add_start_up_upper_bound_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :start_up_upper_bound,
        cons = constraints[:start_up_upper_bound],
        start_up_vars = variables[:start_up].container,
        units_on_vars = variables[:units_on].container

        indices = _append_variable_ids(connection, table_name, ["units_on", "start_up"])

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    start_up_vars[row.start_up_id] <= units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
end
