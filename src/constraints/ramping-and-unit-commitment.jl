export add_ramping_and_unit_commitment_constraints!

"""
    add_ramping_and_unit_commitment_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
        profiles
    )

Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
"""
function add_ramping_constraints!(connection, model, variables, expressions, constraints, profiles)
    indices_dict = Dict(
        table_name => _append_ramping_data_to_indices(connection, table_name) for
        table_name in (
            :min_output_flow_with_unit_commitment,
            :max_ramp_without_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
        )
    )

    ## Expressions used by the ramping and unit commitment constraints
    # - Expression to have the product of the profile and the capacity paramters
    profile_times_capacity = Dict(
        table_name => begin
            indices = indices_dict[table_name]
            [
                _profile_aggregate(
                    profiles.rep_period,
                    (row.profile_name, row.year, row.rep_period),
                    row.time_block_start:row.time_block_end,
                    Statistics.mean,
                    1.0,
                ) * row.capacity for row in indices
            ]
        end for table_name in (
            :min_output_flow_with_unit_commitment,
            :max_ramp_without_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
        )
    )

    # - Flow that is above the minimum operating point of the asset
    for table_name in (
        :min_output_flow_with_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
        :max_ramp_with_unit_commitment,
    )
        cons = constraints[table_name]
        indices = indices_dict[table_name]
        attach_expression!(
            cons,
            :flow_above_min_operating_point,
            [
                @expression(
                    model,
                    outgoing_flow -
                    profile_times_capacity[table_name][row.id] * row.min_operating_point * units_on
                ) for (row, outgoing_flow, units_on) in
                zip(indices, cons.expressions[:outgoing], cons.expressions[:units_on])
            ],
        )
    end

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
    # - Limit to the units on (i.e. commitment)
    let table_name = :limit_units_on, cons = constraints[table_name]
        indices = _append_available_units_data(connection, table_name)
        expr_avail = expressions[:available_asset_units].expressions[:assets]
        attach_constraint!(
            model,
            cons,
            :limit_units_on,
            [
                @constraint(
                    model,
                    units_on ≤ sum(expr_avail[avail_id] for avail_id in row.avail_indices),
                    base_name = "limit_units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (units_on, row) in zip(variables[:units_on].container, indices)
            ],
        )
    end

    # - Minimum output flow above the minimum operating point
    let table_name = :min_output_flow_with_unit_commitment, cons = constraints[table_name]
        indices = indices_dict[table_name]
        attach_constraint!(
            model,
            cons,
            :min_output_flow_with_unit_commitment,
            [
                @constraint(
                    model,
                    flow_above_min_operating_point ≥ 0,
                    base_name = "min_output_flow_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, flow_above_min_operating_point) in
                zip(indices, cons.expressions[:flow_above_min_operating_point])
            ],
        )
    end

    # - Maximum output flow above the minimum operating point
    let table_name = :max_output_flow_with_basic_unit_commitment, cons = constraints[table_name]
        indices = indices_dict[table_name]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    flow_above_min_operating_point ≤
                    (1 - row.min_operating_point) *
                    profile_times_capacity[table_name][row.id] *
                    units_on,
                    base_name = "max_output_flow_with_basic_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, flow_above_min_operating_point, units_on) in zip(
                    indices,
                    cons.expressions[:flow_above_min_operating_point],
                    cons.expressions[:units_on],
                )
            ],
        )
    end

    let table_name = :max_ramp_with_unit_commitment, cons = constraints[table_name]
        indices = indices_dict[table_name]
        ## Ramping Constraints with unit commitment
        # Note: We start ramping constraints from the second timesteps_block
        # We filter and group the indices per asset and representative period
        # get the units on column to get easier the id - 1, i.e., the previous one
        units_on = cons.expressions[:units_on]

        # - Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_up_with_unit_commitment,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    @constraint(
                        model,
                        cons.expressions[:flow_above_min_operating_point][row.id] -
                        cons.expressions[:flow_above_min_operating_point][row.id-1] ≤
                        row.max_ramp_up *
                        min_outgoing_flow_duration *
                        profile_times_capacity[table_name][row.id] *
                        units_on[row.id],
                        base_name = "max_ramp_up_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )

        # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_down_with_unit_commitment,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    @constraint(
                        model,
                        cons.expressions[:flow_above_min_operating_point][row.id] -
                        cons.expressions[:flow_above_min_operating_point][row.id-1] ≥
                        -row.max_ramp_down *
                        min_outgoing_flow_duration *
                        profile_times_capacity[table_name][row.id] *
                        units_on[row.id-1],
                        base_name = "max_ramp_down_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )
    end

    let table_name = :max_ramp_without_unit_commitment, cons = constraints[table_name]
        indices = indices_dict[table_name]
        ## Ramping Constraints without unit commitment
        # Note: We start ramping constraints from the second timesteps_block
        # We filter and group the indices per asset and representative period that does not have the unit_commitment methods

        # - Maximum ramp-up rate limit to the flow (no unit commitment variables)
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_up_without_unit_commitment,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id] -
                        cons.expressions[:outgoing][row.id-1] ≤
                        row.max_ramp_up *
                        min_outgoing_flow_duration *
                        profile_times_capacity[table_name][row.id],
                        base_name = "max_ramp_up_without_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )

        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_down_without_unit_commitment,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id] -
                        cons.expressions[:outgoing][row.id-1] ≥
                        -row.max_ramp_down *
                        min_outgoing_flow_duration *
                        profile_times_capacity[table_name][row.id],
                        base_name = "max_ramp_down_without_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )
    end
end

function _append_ramping_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset.capacity,
            asset.min_operating_point,
            asset.max_ramp_up,
            asset.max_ramp_down,
            assets_profiles.profile_name
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        ORDER BY cons.id
        ",
    )
end

function _append_available_units_data(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.year) AS year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ARRAY_AGG(expr_avail.id) AS avail_indices,
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end
