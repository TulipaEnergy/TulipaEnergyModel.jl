export add_storage_constraints!

"""
    add_storage_constraints!(connection, model, variables, expressions, constraints, profiles)

Adds the storage asset constraints to the model.
"""
function add_storage_constraints!(connection, model, variables, expressions, constraints, profiles)
    var_storage_level_rep_period = variables[:storage_level_rep_period]
    var_storage_level_over_clustered_year = variables[:storage_level_over_clustered_year]

    ## REP-PERIOD CONSTRAINTS (within a representative period)
    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_rep_period, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_rep_period].container
        indices = _append_storage_data_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            :balance_storage_rep_period,
            [
                begin
                    profile_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.inflows_profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        sum,
                        0.0,
                    )
                    initial_storage_level = row.initial_storage_level

                    if row.time_block_start == 1 && !ismissing(initial_storage_level)
                        # Initial storage is a Float64
                        @constraint(
                            model,
                            var_storage_level[row.id] ==
                            initial_storage_level +
                            profile_agg * row.storage_inflows +
                            incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.time_block_start > 1
                            var_storage_level[row.id-1]
                        else
                            # Find last id of this group (there are probably cheaper ways, in case this becomes expensive)
                            last_id = only([
                                row[1] for row in DuckDB.query(
                                    connection,
                                    "SELECT
                                        MAX(id)
                                    FROM cons_$table_name
                                    WHERE asset = '$(row.asset)' AND year = $(row.year) AND rep_period = $(row.rep_period)
                                    ",
                                )
                            ])::Int
                            var_storage_level[last_id]
                        end
                        computed_storage_loss_coef = 1.0
                        if row.storage_loss_from_stored_energy > 0.0
                            duration = row.time_block_end - row.time_block_start + 1
                            computed_storage_loss_coef =
                                (1 - row.storage_loss_from_stored_energy)^duration
                        end
                        @constraint(
                            model,
                            var_storage_level[row.id] ==
                            computed_storage_loss_coef * previous_level +
                            profile_agg * row.storage_inflows +
                            incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for (row, incoming_flow, outgoing_flow) in
                zip(indices, cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )

        available_energy_capacity_simple_method =
            expressions[:available_energy_capacity_simple_method].expressions[:energy_capacity]

        # - Maximum storage level
        attach_constraint!(
            model,
            cons,
            :max_storage_level_rep_period_limit,
            [
                begin
                    max_storage_level_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.max_storage_level_profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @constraint(
                        model,
                        var_storage_level ≤
                        max_storage_level_agg *
                        available_energy_capacity_simple_method[row.avail_energy_capacity_id],
                        base_name = "max_storage_level_rep_period_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for
                (row, var_storage_level) in zip(indices, var_storage_level_rep_period.container)
            ],
        )

        # - Minimum storage level
        attach_constraint!(
            model,
            cons,
            :min_storage_level_rep_period_limit,
            [
                begin
                    min_storage_level_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.min_storage_level_profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        0.0,
                    )
                    @constraint(
                        model,
                        var_storage_level ≥
                        min_storage_level_agg *
                        available_energy_capacity_simple_method[row.avail_energy_capacity_id],
                        base_name = "min_storage_level_rep_period_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for
                (row, var_storage_level) in zip(indices, var_storage_level_rep_period.container)
            ],
        )
    end

    ## OVER-CLUSTERED-YEAR CONSTRAINTS (between representative periods)

    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_over_clustered_year, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_over_clustered_year].container
        indices = _append_storage_data_to_indices(connection, table_name)

        # This assumes an ordering of the time blocks, that is guaranteed by the append function above
        # The storage_inflows have been moved here
        attach_constraint!(
            model,
            cons,
            :balance_storage_over_clustered_year,
            [
                begin
                    initial_storage_level = row.initial_storage_level

                    if row.period_block_start == 1 && !ismissing(initial_storage_level)
                        # Initial storage is a Float64
                        @constraint(
                            model,
                            var_storage_level_over_clustered_year.container[row.id] ==
                            initial_storage_level + inflows_agg + incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.period_block_start > 1
                            var_storage_level[row.id-1]
                        else
                            last_id = only([
                                row[1] for row in DuckDB.query(
                                    connection,
                                    "SELECT
                                        MAX(id)
                                    FROM cons_$table_name
                                    WHERE asset = '$(row.asset)' AND year = $(row.year)
                                    ",
                                )
                            ])::Int
                            var_storage_level[last_id]
                        end
                        computed_storage_loss_coef = 1.0
                        if row.storage_loss_from_stored_energy > 0.0
                            computed_storage_loss_coef =
                                (1 - row.storage_loss_from_stored_energy)^row.duration_period_block
                        end
                        @constraint(
                            model,
                            var_storage_level_over_clustered_year.container[row.id] ==
                            computed_storage_loss_coef * previous_level +
                            inflows_agg +
                            incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    end
                end for (row, incoming_flow, outgoing_flow, inflows_agg) in zip(
                    indices,
                    cons.expressions[:incoming],
                    cons.expressions[:outgoing],
                    cons.coefficients[:inflows_profile_aggregation],
                )
            ],
        )

        available_energy_capacity_simple_method =
            expressions[:available_energy_capacity_simple_method].expressions[:energy_capacity]

        # - Maximum storage level
        attach_constraint!(
            model,
            cons,
            :max_storage_level_over_clustered_year_limit,
            [
                begin
                    max_storage_level_agg = _profile_aggregate(
                        profiles.over_clustered_year,
                        (row.max_storage_level_profile_name, row.year),
                        row.period_block_start:row.period_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @constraint(
                        model,
                        var_storage_level ≤
                        max_storage_level_agg *
                        available_energy_capacity_simple_method[row.avail_energy_capacity_id],
                        base_name = "max_storage_level_over_clustered_year_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                    )
                end for (row, var_storage_level) in
                zip(indices, var_storage_level_over_clustered_year.container)
            ],
        )

        # - Minimum storage level
        attach_constraint!(
            model,
            cons,
            :min_storage_level_over_clustered_year_limit,
            [
                begin
                    min_storage_level_agg = _profile_aggregate(
                        profiles.over_clustered_year,
                        (row.min_storage_level_profile_name, row.year),
                        row.period_block_start:row.period_block_end,
                        Statistics.mean,
                        0.0,
                    )
                    @constraint(
                        model,
                        var_storage_level ≥
                        min_storage_level_agg *
                        available_energy_capacity_simple_method[row.avail_energy_capacity_id],
                        base_name = "min_storage_level_over_clustered_year_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                    )
                end for (row, var_storage_level) in
                zip(indices, var_storage_level_over_clustered_year.container)
            ],
        )
    end
end

function _append_storage_data_to_indices(connection, table_name)
    join_duration = ""
    select_duration = ""

    if table_name == :balance_storage_over_clustered_year
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TEMP TABLE t_duration_over_clustered_year AS
            SELECT
                cons.asset,
                cons.year,
                cons.period_block_start,
                SUM(mapping.num_timesteps) AS duration_period_block
            FROM cons_balance_storage_over_clustered_year AS cons
            LEFT JOIN timeframe_data AS mapping
                ON mapping.year = cons.year
                AND mapping.period BETWEEN cons.period_block_start AND cons.period_block_end
            GROUP BY cons.asset, cons.year, cons.period_block_start
            """,
        )

        join_duration = """
        LEFT JOIN t_duration_over_clustered_year AS duration
            ON cons.asset = duration.asset
            AND cons.year = duration.year
            AND cons.period_block_start = duration.period_block_start
        """
        select_duration = "duration.duration_period_block,"
    end

    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            $select_duration
            asset.capacity,
            asset_commission.investment_limit,
            asset_commission.storage_loss_from_stored_energy,
            asset_milestone.initial_storage_level,
            asset_milestone.storage_inflows,
            inflows_profile.profile_name AS inflows_profile_name,
            max_storage_level_profile.profile_name AS max_storage_level_profile_name,
            min_storage_level_profile.profile_name AS min_storage_level_profile_name,
            expr_avail.id AS avail_energy_capacity_id
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.year = asset_commission.commission_year
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.year = asset_milestone.milestone_year
        LEFT JOIN expr_available_energy_capacity_simple_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT OUTER JOIN assets_profiles AS inflows_profile
            ON cons.asset = inflows_profile.asset
            AND cons.year = inflows_profile.commission_year
            AND inflows_profile.profile_type = 'inflows'
        LEFT OUTER JOIN assets_profiles AS max_storage_level_profile
            ON cons.asset = max_storage_level_profile.asset
            AND cons.year = max_storage_level_profile.commission_year
            AND max_storage_level_profile.profile_type = 'max_storage_level'
        LEFT OUTER JOIN assets_profiles AS min_storage_level_profile
            ON cons.asset = min_storage_level_profile.asset
            AND cons.year = min_storage_level_profile.commission_year
            AND min_storage_level_profile.profile_type = 'min_storage_level'
        $join_duration
        ORDER BY cons.id
        ",
    )
end
