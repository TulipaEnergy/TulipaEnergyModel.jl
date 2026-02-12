export add_shut_down_domain_2var_constraints!

"""
    add_shut_down_domain_2var_constraints!(model, constraints)

Adds the unit commitment logic constraint (i.e., start up - shut down = units_on difference) to the model.
"""
function add_shut_down_domain_2var_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :shut_down_domain_2var, cons = constraints[table_name]
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
                        @constraint(model, 0 == 0) # TODO: Placeholder for case k = 1
                    # @constraint(
                    #     model,
                    #     start_up[row.start_up_id] >= units_on[row.units_on_id],
                    #     base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    # )
                    else
                        @constraint(
                            model,
                            start_up[row.start_up_id] >=
                            units_on[row.units_on_id] - units_on[row.units_on_id-1],
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end
end
