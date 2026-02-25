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
    # - Capacity limits for transport flows including lower bounds and upper bounds
    add_capacity_limits_transport_flows!(
        connection,
        model,
        variables,
        expressions,
        constraints,
        profiles,
    )

    # - Minimum output flows limit if any of the flows is transport flow
    # - This allows some negative flows but not all negative flows, so transport flows can pass
    # - through this asset
    # - Holds for producers, conversion and storage assets
    add_min_outgoing_flow_for_transport_flows_without_unit_commitment(model, constraints)

    # - Minimum output vintage flows limit if any of the flows is transport flow
    # - Since regular flow is a special case of the vintage_flow, vintage_flow has to have the same
    # - constraint as the regular flow above
    add_min_outgoing_flow_for_transport_vintage_flows(model, constraints)

    # - Minimum input flows limit if any of the flows is transport flow
    # - This allows some negative flows but not all negative flows, so transport flows can pass
    # - through this asset
    # - Holds for conversion and storage assets
    add_min_incoming_flow_for_transport_flows(model, constraints)

    return
end

function add_capacity_limits_transport_flows!(
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

    # - Capacity limits for transport flows
    let table_name = :transport_flow_limit_simple_method, cons = constraints[table_name]
        indices = _append_transport_data_to_indices(connection)
        var_flow = variables[:flow].container

        availability_agg_iterator = (
            _profile_aggregate(
                profiles.rep_period,
                (row.profile_name, row.milestone_year, row.rep_period),
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
                    base_name = "max_transport_flow_limit_simple_method[($(row.from_asset),$(row.to_asset)),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
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
                    base_name = "min_transport_flow_limit_simple_method[($(row.from_asset),$(row.to_asset)),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, lower_bound_transport_flow) in
                zip(indices, cons.expressions[:lower_bound_transport_flow])
            ],
        )
    end
end

function add_min_outgoing_flow_for_transport_flows_without_unit_commitment(model, constraints)
    let table_name = :min_outgoing_flow_for_transport_flows_without_unit_commitment,
        cons_name = Symbol("min_output_flows_limit_for_transport_flows_without_unit_commitment")

        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≥ 0,
                    base_name = "$cons_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow) in
                zip(constraints[table_name].indices, constraints[table_name].expressions[:outgoing])
            ],
        )
    end
end

function add_min_outgoing_flow_for_transport_vintage_flows(model, constraints)
    let table_name = :min_outgoing_flow_for_transport_vintage_flows,
        cons_name = Symbol("min_output_flows_limit_for_transport_vintage_flows")

        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≥ 0,
                    base_name = "$cons_name[$(row.asset),$(row.milestone_year),$(row.commission_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow) in
                zip(constraints[table_name].indices, constraints[table_name].expressions[:outgoing])
            ],
        )
    end
end

function add_min_incoming_flow_for_transport_flows(model, constraints)
    let table_name = :min_incoming_flow_for_transport_flows,
        cons_name = Symbol("min_input_flows_limit_for_transport_flows")

        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    incoming_flow ≥ 0,
                    base_name = "$cons_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow) in
                zip(constraints[table_name].indices, constraints[table_name].expressions[:incoming])
            ],
        )
    end
end

function _append_transport_data_to_indices(connection)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id AS id,
            cons.from_asset AS from_asset,
            cons.to_asset AS to_asset,
            cons.milestone_year AS milestone_year,
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
            AND cons.milestone_year = expr_avail.milestone_year
        LEFT OUTER JOIN flows_profiles
            ON cons.from_asset = flows_profiles.from_asset
            AND cons.to_asset = flows_profiles.to_asset
            AND cons.milestone_year = flows_profiles.milestone_year
            AND flows_profiles.profile_type = 'availability'
        ORDER BY cons.id
        ",
    )
end
