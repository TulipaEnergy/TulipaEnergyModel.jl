export add_ramping_and_unit_commitment_constraints!

"""
    add_ramping_and_unit_commitment_constraints!(model, graph, ...)

Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
"""
function add_ramping_constraints!(model, variables, constraints, graph, sets)
    # unpack from sets
    accumulated_units_lookup = sets[:accumulated_units_lookup]

    ## unpack from model
    accumulated_units = model[:accumulated_units]

    ## Expressions used by the ramping and unit commitment constraints
    # - Expression to have the product of the profile and the capacity paramters
    profile_times_capacity = Dict(
        table_name => begin
            cons = constraints[table_name]
            [
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) * graph[row.asset].capacity for row in eachrow(cons.indices)
            ]
        end for table_name in (
            :ramping_with_unit_commitment,
            :ramping_without_unit_commitment,
            :max_ramp_without_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
        )
    )

    # - Flow that is above the minimum operating point of the asset
    for table_name in (
        :ramping_with_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
        :max_ramp_with_unit_commitment,
    )
        cons = constraints[table_name]
        attach_expression!(
            cons,
            :flow_above_min_operating_point,
            [
                @expression(
                    model,
                    cons.expressions[:outgoing][row.index] -
                    profile_times_capacity[table_name][row.index] *
                    graph[row.asset].min_operating_point *
                    cons.expressions[:units_on][row.index]
                ) for row in eachrow(cons.indices)
            ],
        )
    end

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
    # - Limit to the units on (i.e. commitment)
    let
        table_name = :limit_units_on
        cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            :limit_units_on,
            [
                @constraint(
                    model,
                    units_on ≤ accumulated_units[accumulated_units_lookup[(row.asset, row.year)]],
                    base_name = "limit_units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (units_on, row) in zip(variables[:units_on].container, eachrow(cons.indices))
            ],
        )
    end

    # - Minimum output flow above the minimum operating point
    let
        table_name = :ramping_with_unit_commitment
        cons = constraints[table_name]
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
                zip(eachrow(cons.indices), cons.expressions[:flow_above_min_operating_point])
            ],
        )
    end

    # - Maximum output flow above the minimum operating point
    let
        table_name = :max_output_flow_with_basic_unit_commitment
        cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    cons.expressions[:flow_above_min_operating_point][row.index] ≤
                    (1 - graph[row.asset].min_operating_point) *
                    profile_times_capacity[table_name][row.index] *
                    cons.expressions[:units_on][row.index],
                    base_name = "max_output_flow_with_basic_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in eachrow(cons.indices)
            ],
        )
    end

    let
        ## Ramping Constraints with unit commitment
        # Note: We start ramping constraints from the second timesteps_block
        # We filter and group the dataframe per asset and representative period
        table_name = :max_ramp_with_unit_commitment
        cons = constraints[table_name]
        # get the units on column to get easier the index - 1, i.e., the previous one
        units_on = cons.expressions[:units_on]

        # - Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_up_with_unit_commitment,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0) # Placeholder for case k = 1
                    else
                        @constraint(
                            model,
                            cons.expressions[:flow_above_min_operating_point][row.index] -
                            cons.expressions[:flow_above_min_operating_point][row.index-1] ≤
                            graph[row.asset].max_ramp_up *
                            row.min_outgoing_flow_duration *
                            profile_times_capacity[table_name][row.index] *
                            units_on[row.index],
                            base_name = "max_ramp_up_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in eachrow(cons.indices)
            ],
        )

        # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_down_with_unit_commitment,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0) # Placeholder for case k = 1
                    else
                        @constraint(
                            model,
                            cons.expressions[:flow_above_min_operating_point][row.index] -
                            cons.expressions[:flow_above_min_operating_point][row.index-1] ≥
                            -graph[row.asset].max_ramp_down *
                            row.min_outgoing_flow_duration *
                            profile_times_capacity[table_name][row.index] *
                            units_on[row.index-1],
                            base_name = "max_ramp_down_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in eachrow(cons.indices)
            ],
        )
    end

    let
        table_name = :max_ramp_without_unit_commitment
        cons = constraints[table_name]
        ## Ramping Constraints without unit commitment
        # Note: We start ramping constraints from the second timesteps_block
        # We filter and group the dataframe per asset and representative period that does not have the unit_commitment methods

        # - Maximum ramp-up rate limit to the flow (no unit commitment variables)
        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_up_without_unit_commitment,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0) # Placeholder for case k = 1
                    else
                        @constraint(
                            model,
                            cons.expressions[:outgoing][row.index] -
                            cons.expressions[:outgoing][row.index-1] ≤
                            graph[row.asset].max_ramp_up *
                            row.min_outgoing_flow_duration *
                            profile_times_capacity[table_name][row.index],
                            base_name = "max_ramp_up_without_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in eachrow(cons.indices)
            ],
        )
        #base_name = "max_ramp_down_without_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"

        attach_constraint!(
            model,
            constraints[table_name],
            :max_ramp_up_without_unit_commitment,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0) # Placeholder for case k = 1
                    else
                        @constraint(
                            model,
                            cons.expressions[:outgoing][row.index] -
                            cons.expressions[:outgoing][row.index-1] ≥
                            -graph[row.asset].max_ramp_down *
                            row.min_outgoing_flow_duration *
                            profile_times_capacity[table_name][row.index],
                            base_name = "max_ramp_down_without_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in eachrow(cons.indices)
            ],
        )
    end
end
