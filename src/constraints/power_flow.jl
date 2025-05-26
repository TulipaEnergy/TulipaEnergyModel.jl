export add_dc_power_flow_constraints!

"""
    add_dc_power_flow_constraints!(connection, model, variables, constraints, model_parameters)

Adds the dc power flow constraints to the model.
"""
function add_dc_power_flow_constraints!(connection, model, variables, constraints, model_parameters)
    let table_name = :dc_power_flow, cons = constraints[:dc_power_flow]
        indices = _append_power_flow_data_to_indices(connection, table_name)

        var_flow = variables[:flow].container
        var_angle = variables[:electricity_angle].container

        power_system_base = model_parameters.power_system_base

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    row.reactance * var_flow[row.var_flow_id] ==
                    power_system_base *
                    (var_angle[row.var_angle_from_asset_id] - var_angle[row.var_angle_to_asset_id]),
                    base_name = "$table_name[$(row.from_asset),$(row.to_asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    return
end

function _append_power_flow_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            flow.id as var_flow_id,
            angle_from_asset.id as var_angle_from_asset_id,
            angle_to_asset.id as var_angle_to_asset_id,
            fm.reactance
        FROM cons_$table_name AS cons
        LEFT JOIN var_flow as flow
            ON cons.from_asset = flow.from_asset
            AND cons.to_asset = flow.to_asset
            AND cons.year = flow.year
            AND cons.rep_period = flow.rep_period
            -- Check for overlapping ranges, given the constraint has the highest resolution
            AND cons.time_block_start >= flow.time_block_start
            AND cons.time_block_end <= flow.time_block_end
        LEFT JOIN var_electricity_angle as angle_from_asset
            ON cons.from_asset = angle_from_asset.asset
            AND cons.year = angle_from_asset.year
            AND cons.rep_period = angle_from_asset.rep_period
            AND cons.time_block_start >= angle_from_asset.time_block_start
            AND cons.time_block_end <= angle_from_asset.time_block_end
        LEFT JOIN var_electricity_angle as angle_to_asset
            ON cons.to_asset = angle_to_asset.asset
            AND cons.year = angle_to_asset.year
            AND cons.rep_period = angle_to_asset.rep_period
            AND cons.time_block_start >= angle_to_asset.time_block_start
            AND cons.time_block_end <= angle_to_asset.time_block_end
        LEFT JOIN flow_milestone as fm
            ON cons.from_asset = fm.from_asset
            AND cons.to_asset = fm.to_asset
            AND cons.year = fm.milestone_year
        ORDER BY cons.id
        ",
    )
end
