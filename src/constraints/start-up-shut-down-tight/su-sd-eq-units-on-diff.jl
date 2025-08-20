export add_su_sd_eq_units_on_diff_constraints!

"""
    add_su_sd_eq_units_on_diff_constraints!(model, constraints)

Adds the start up - shut down = units_on difference to the model.
"""
function add_su_sd_eq_units_on_diff_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :su_sd_eq_units_on_diff, cons = constraints[:su_sd_eq_units_on_diff]
        units_on = variables[:units_on].container
        start_up = variables[:start_up].container
        shut_down = variables[:shut_down].container

        indices =
            _append_variable_ids(connection, table_name, ["units_on", "start_up", "shut_down"])

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
                            units_on[row.units_on_id] - units_on[row.units_on_id-1] ==
                            start_up[row.start_up_id] - shut_down[row.shut_down_id],
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end
end
