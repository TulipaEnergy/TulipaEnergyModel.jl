export add_ramping_and_unit_commitment_constraints!

"""
    add_ramping_and_unit_commitment_constraints!(model, graph, ...)

Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
"""
function add_ramping_constraints!(model, variables, constraints, graph, sets)
    # unpack from sets
    Ar = sets[:Ar]
    Auc = sets[:Auc]
    Auc_basic = sets[:Auc_basic]
    accumulated_units_lookup = sets[:accumulated_units_lookup]

    ## unpack from model
    accumulated_units = model[:accumulated_units]

    ## unpack from constraints
    cons_with = constraints[:ramping_with_unit_commitment]
    cons_without = constraints[:ramping_without_unit_commitment]
    outgoing_flow = cons_without.expressions[:outgoing]

    ## Expressions used by the ramping and unit commitment constraints
    # - Expression to have the product of the profile and the capacity paramters
    profile_times_capacity = Dict(
        key => begin
            table_name = Symbol("ramping_$(key)_unit_commitment")
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
        end for key in (:with, :without)
    )

    # - Flow that is above the minimum operating point of the asset
    flow_above_min_operating_point =
        model[:flow_above_min_operating_point] = [
            @expression(
                model,
                cons_with.expressions[:outgoing][row.index] -
                profile_times_capacity[:with][row.index] *
                graph[row.asset].min_operating_point *
                cons_with.expressions[:units_on][row.index]
            ) for row in eachrow(cons_with.indices)
        ]

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
    # - Limit to the units on (i.e. commitment)
    # TODO: When this becomes a TulipaConstraint, attach `:limit_units_on`
    model[:limit_units_on] = [
        @constraint(
            model,
            units_on ≤ accumulated_units[accumulated_units_lookup[(row.asset, row.year)]],
            base_name = "limit_units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for (units_on, row) in
        zip(variables[:units_on].container, eachrow(variables[:units_on].indices))
    ]

    # - Minimum output flow above the minimum operating point
    attach_constraint!(
        model,
        cons_with,
        :min_output_flow_with_unit_commitment,
        [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] ≥ 0,
                base_name = "min_output_flow_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for row in eachrow(cons_with.indices)
        ],
    )

    # - Maximum output flow above the minimum operating point
    attach_constraint!(
        model,
        cons_with,
        :max_output_flow_with_unit_commitment,
        [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] ≤
                (1 - graph[row.asset].min_operating_point) *
                profile_times_capacity[:with][row.index] *
                cons_with.expressions[:units_on][row.index],
                base_name = "max_output_flow_with_basic_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for row in eachrow(cons_with.indices) if row.asset ∈ Auc_basic
        ],
    )

    ## Ramping Constraints with unit commitment
    # Note: We start ramping constraints from the second timesteps_block
    # We filter and group the dataframe per asset and representative period
    df_grouped = DataFrames.groupby(cons_with.indices, [:asset, :year, :rep_period])

    # get the units on column to get easier the index - 1, i.e., the previous one
    units_on = cons_with.expressions[:units_on]

    #- Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar && a ∈ Auc_basic)
            continue
        end
        model[Symbol("max_ramp_up_with_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] -
                flow_above_min_operating_point[row.index-1] ≤
                graph[row.asset].max_ramp_up *
                row.min_outgoing_flow_duration *
                profile_times_capacity[:with][row.index] *
                units_on[row.index],
                base_name = "max_ramp_up_with_unit_commitment[$a,$y,$rp,$(row.time_block_start):$(row.time_block_end)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end

    # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar && a ∈ Auc_basic)
            continue
        end
        model[Symbol("max_ramp_down_with_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] -
                flow_above_min_operating_point[row.index-1] ≥
                -graph[row.asset].max_ramp_down *
                row.min_outgoing_flow_duration *
                profile_times_capacity[:with][row.index] *
                units_on[row.index-1],
                base_name = "max_ramp_down_with_unit_commitment[$a,$y,$rp,$(row.time_block_start):$(row.time_block_end)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end

    ## Ramping Constraints without unit commitment
    # Note: We start ramping constraints from the second timesteps_block
    # We filter and group the dataframe per asset and representative period that does not have the unit_commitment methods
    df_grouped = DataFrames.groupby(cons_without.indices, [:asset, :year, :rep_period])

    # - Maximum ramp-up rate limit to the flow (no unit commitment variables)
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar) || a ∈ Auc # !(a ∈ Ar \ Auc) = !(a ∈ Ar ∩ Aucᶜ) = !(a ∈ Ar && a ∉ Auc) = a ∉ Ar || a ∈ Auc
            continue
        end
        model[Symbol("max_ramp_up_without_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                outgoing_flow[row.index] - outgoing_flow[row.index-1] ≤
                graph[row.asset].max_ramp_up *
                row.min_outgoing_flow_duration *
                profile_times_capacity[:without][row.index],
                base_name = "max_ramp_up_without_unit_commitment[$a,$y,$rp,$(row.time_block_start):$(row.time_block_end)]"
            ) for
            (k, row) in enumerate(eachrow(sub_df)) if k > 1 && outgoing_flow[row.index] != 0
        ]
    end

    # - Maximum ramp-down rate limit to the flow (no unit commitment variables)
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar) || a ∈ Auc # !(a ∈ Ar \ Auc) = !(a ∈ Ar ∩ Aucᶜ) = !(a ∈ Ar && a ∉ Auc) = a ∉ Ar || a ∈ Auc
            continue
        end
        model[Symbol("max_ramp_down_without_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                outgoing_flow[row.index] - outgoing_flow[row.index-1] ≥
                -graph[row.asset].max_ramp_down *
                row.min_outgoing_flow_duration *
                profile_times_capacity[:without][row.index],
                base_name = "max_ramp_down_without_unit_commitment[$a,$y,$rp,$(row.time_block_start):$(row.time_block_end)]"
            ) for
            (k, row) in enumerate(eachrow(sub_df)) if k > 1 && outgoing_flow[row.index] != 0
        ]
    end
end
