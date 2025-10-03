export add_start_up_lower_bound_constraints!

"""
    add_start_up_lower_bound_constraints!(connection, model, variables, expressions, constraints)

Adds the compact start up constraints to the model.
"""
function add_start_up_lower_bound_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :start_up_lower_bound, cons = constraints[table_name]
        units_on = variables[:units_on].container
        start_up = variables[:start_up].container

        indices = _append_variable_ids(connection, table_name, ["units_on", "start_up"])

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0)
                    else
                        @constraint(
                            model,
                            units_on[row.units_on_id] - units_on[row.units_on_id-1] <=
                            start_up[row.start_up_id],
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end
end
