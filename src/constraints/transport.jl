export add_transport_constraints!

"""
    add_transport_constraints!(connection, model, variables, expressions, constraints, profiles)

Adds the transport flow constraints to the model.
"""
function add_transport_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles,
)
    ## unpack from model
    expr_avail = expressions[:available_flow_units_simple_method]
    expr_avail_export = expr_avail.expressions[:export]
    expr_avail_import = expr_avail.expressions[:import]

    let table_name = :transport_flow_limit_simple_method, cons = constraints[table_name]
        indices = _append_transport_data_to_indices(connection)
        var_flow = variables[:flow].container

        availability_agg_iterator = (
            _profile_aggregate(
                profiles.rep_period,
                (row.profile_name, row.year, row.rep_period),
                row.time_block_start:row.time_block_end,
                Statistics.mean,
                1.0,
            ) for row in indices
        )

        # - Create upper limit of transport flow
        attach_expression!(
            cons,
            :upper_bound_transport_flow,
            [
                @expression(
                    model,
                    availability_agg * row.capacity * expr_avail_export[row.avail_id]
                ) for (row, availability_agg) in zip(indices, availability_agg_iterator)
            ],
        )

        # - Create lower limit of transport flow
        attach_expression!(
            cons,
            :lower_bound_transport_flow,
            [
                @expression(
                    model,
                    availability_agg * row.capacity * expr_avail_import[row.avail_id]
                ) for (row, availability_agg) in zip(indices, availability_agg_iterator)
            ],
        )

        ## Constraints that define bounds for an investable transport flow

        # - Max transport flow limit
        attach_constraint!(
            model,
            cons,
            :max_transport_flow_limit_simple_method,
            [
                @constraint(
                    model,
                    var_flow[row.var_flow_id] ≤ upper_bound_transport_flow,
                    base_name = "max_transport_flow_limit_simple_method[($(row.from_asset),$(row.to_asset)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, upper_bound_transport_flow) in
                zip(indices, cons.expressions[:upper_bound_transport_flow])
            ],
        )

        # - Min transport flow limit
        attach_constraint!(
            model,
            cons,
            :min_transport_flow_limit_simple_method,
            [
                @constraint(
                    model,
                    var_flow[row.var_flow_id] ≥ -lower_bound_transport_flow,
                    base_name = "min_transport_flow_limit_simple_method[($(row.from_asset),$(row.to_asset)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, lower_bound_transport_flow) in
                zip(indices, cons.expressions[:lower_bound_transport_flow])
            ],
        )
    end

    return
end

function _append_transport_data_to_indices(connection)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id AS id,
            cons.from_asset AS from_asset,
            cons.to_asset AS to_asset,
            cons.year AS year,
            cons.rep_period AS rep_period,
            cons.time_block_start AS time_block_start,
            cons.time_block_end AS time_block_end,
            cons.var_flow_id AS var_flow_id,
            flow.capacity AS capacity,
            expr_avail.id AS avail_id,
            flows_profiles.profile_name AS profile_name,
        FROM cons_transport_flow_limit_simple_method AS cons
        LEFT JOIN flow
            ON cons.from_asset = flow.from_asset
            AND cons.to_asset = flow.to_asset
        LEFT JOIN expr_available_flow_units_simple_method AS expr_avail
            ON cons.from_asset = expr_avail.from_asset
            AND cons.to_asset = expr_avail.to_asset
            AND cons.year = expr_avail.milestone_year
        LEFT OUTER JOIN flows_profiles
            ON cons.from_asset = flows_profiles.from_asset
            AND cons.to_asset = flows_profiles.to_asset
            AND cons.year = flows_profiles.year
            AND flows_profiles.profile_type = 'availability'
        ORDER BY cons.id
        ",
    )
end
