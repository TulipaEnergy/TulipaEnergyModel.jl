"""
    add_storage_constraints!(connection, model, variables, expressions, constraints, profiles)

Adds the storage asset constraints to the model.
"""
function add_storage_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles;
    rolling_horizon = false,
)
    var_storage_level_intra_rep_period = variables[:storage_level_intra_rep_period]
    var_storage_level_inter_period = variables[:storage_level_inter_period]
    var_accumulated_storage_level_intra_rep_period =
        variables[:accumulated_storage_level_intra_rep_period]
    var_max_storage_level_increase_intra_rep_period =
        variables[:max_storage_level_increase_intra_rep_period]
    var_max_storage_level_decrease_intra_rep_period =
        variables[:max_storage_level_decrease_intra_rep_period]
    available_energy_capacity =
        expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]

    rolling_horizon_lookup = if rolling_horizon
        Dict{Int,Int}(
            row.var_storage_id::Int => row.id::Int for
            row in DuckDB.query(connection, "FROM param_initial_storage_level")
        )
    else
        Dict{Int,Int}()
    end

    ## REP-PERIOD CONSTRAINTS (within a representative period)
    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_rep_period, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_intra_rep_period].container
        indices = _append_storage_data_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            :balance_storage_rep_period,
            [
                begin
                    profile_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.inflows_profile_name, row.milestone_year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        sum,
                        0.0,
                    )
                    initial_storage_level = if rolling_horizon && row.time_block_start == 1
                        rolling_horizon_id = rolling_horizon_lookup[row.id]
                        variables[:param_initial_storage_level].container[rolling_horizon_id]
                    else
                        row.initial_storage_level::Union{Float64,Missing}
                    end
                    storage_charging_efficiency = row.storage_charging_efficiency::Float64
                    storage_discharging_efficiency = row.storage_discharging_efficiency::Float64

                    if row.time_block_start == 1 && !ismissing(initial_storage_level)
                        initial_storage_level_in_energy =
                            initial_storage_level *
                            available_energy_capacity[row.avail_energy_capacity_id]
                        @constraint(
                            model,
                            var_storage_level[row.id] ==
                            initial_storage_level_in_energy +
                            profile_agg * row.storage_inflows +
                            storage_charging_efficiency * incoming_flow -
                            outgoing_flow / storage_discharging_efficiency,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.time_block_start > 1
                            var_storage_level[row.previous_id::Int]
                        else
                            var_storage_level[row.cycle_id::Int]
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
                            storage_charging_efficiency * incoming_flow -
                            outgoing_flow / storage_discharging_efficiency,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for (row, incoming_flow, outgoing_flow) in
                zip(indices, cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end

    # - Maximum storage level within a representative period
    let table_name = :max_storage_level_intra_rep_period_limit,
        cons = constraints[table_name],
        indices =
            _append_storage_level_intra_rep_period_bound_data_to_indices(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    max_storage_level_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.max_storage_level_profile_name, row.milestone_year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @constraint(
                        model,
                        var_storage_level_intra_rep_period.container[row.storage_level_id] ≤
                        max_storage_level_agg *
                        available_energy_capacity[row.avail_energy_capacity_id],
                        base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices
            ],
        )
    end

    # - Nonredundant minimum storage level within a representative period
    let table_name = :min_storage_level_intra_rep_period_limit,
        cons = constraints[table_name],
        indices =
            _append_storage_level_intra_rep_period_bound_data_to_indices(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    min_storage_level_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.min_storage_level_profile_name, row.milestone_year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        0.0,
                    )
                    @constraint(
                        model,
                        var_storage_level_intra_rep_period.container[row.storage_level_id] ≥
                        min_storage_level_agg *
                        available_energy_capacity[row.avail_energy_capacity_id],
                        base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices
            ],
        )
    end

    ## inter-period constraints (between representative periods)

    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_inter_period, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_inter_period].container
        indices = _append_storage_data_to_indices(connection, table_name)

        # This assumes an ordering of the time blocks, that is guaranteed by the append function above
        # The storage_inflows have been moved here
        attach_constraint!(
            model,
            cons,
            :balance_storage_inter_period,
            [
                begin
                    initial_storage_level = row.initial_storage_level::Union{Float64,Missing}

                    computed_storage_loss_coef = 1.0
                    if row.storage_loss_from_stored_energy > 0.0
                        computed_storage_loss_coef =
                            (1 - row.storage_loss_from_stored_energy)^row.duration_period_block
                    end

                    if row.period_block_start == 1 && !ismissing(initial_storage_level)
                        initial_storage_level_in_energy =
                            initial_storage_level *
                            available_energy_capacity[row.avail_energy_capacity_id]
                        @constraint(
                            model,
                            var_storage_level_inter_period.container[row.id] ==
                            computed_storage_loss_coef * initial_storage_level_in_energy +
                            accumulated_intra_period,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.period_block_start > 1
                            var_storage_level[row.previous_id::Int]
                        else
                            var_storage_level[row.cycle_id::Int]
                        end
                        @constraint(
                            model,
                            var_storage_level_inter_period.container[row.id] ==
                            computed_storage_loss_coef * previous_level + accumulated_intra_period,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    end
                end for (row, accumulated_intra_period) in
                zip(indices, cons.expressions[:accumulated_intra_period])
            ],
        )
    end

    # - Maximum increase and decrease of accumulated storage within a representative period (6a)
    let table_name = :storage_level_intra_rep_period_bounds, cons = constraints[table_name]
        indices = DuckDB.query(connection, "FROM cons_$table_name ORDER BY id")
        attach_constraint!(
            model,
            cons,
            :max_storage_level_increase_intra_rep_period_limit,
            [
                @constraint(
                    model,
                    var_accumulated_storage_level_intra_rep_period.container[row.accumulated_storage_level_id] ≤
                    var_max_storage_level_increase_intra_rep_period.container[row.max_storage_level_increase_id],
                    base_name = "max_storage_level_increase_intra_rep_period_limit[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
        indices = DuckDB.query(connection, "FROM cons_$table_name ORDER BY id")
        attach_constraint!(
            model,
            cons,
            :max_storage_level_decrease_intra_rep_period_limit,
            [
                @constraint(
                    model,
                    -var_max_storage_level_decrease_intra_rep_period.container[row.max_storage_level_decrease_id] ≤
                    var_accumulated_storage_level_intra_rep_period.container[row.accumulated_storage_level_id],
                    base_name = "max_storage_level_decrease_intra_rep_period_limit[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    # - Maximum inter-period storage level (4a or 6b-6c)
    let table_name = :max_storage_level_inter_period_limit,
        cons = constraints[table_name],
        indices = _append_storage_level_inter_period_bound_data_to_indices(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    conservative =
                        row.inter_period_storage_level_bounds == "inter_and_intra_rep_period"
                    max_storage_level_agg = if conservative
                        _profile_aggregate(
                            profiles.inter_period,
                            (row.max_storage_level_profile_name, row.milestone_year, row.scenario),
                            row.period_block_start:row.period_block_end,
                            minimum,
                            1.0,
                        )
                    else
                        _profile_aggregate(
                            profiles.inter_period,
                            (row.max_storage_level_profile_name, row.milestone_year, row.scenario),
                            row.period_block_start:row.period_block_end,
                            Statistics.mean,
                            1.0,
                        )
                    end
                    if conservative
                        initial_storage_level = row.initial_storage_level::Union{Float64,Missing}
                        loss_coefficient = 1.0 - (row.storage_loss_from_stored_energy::Float64)
                        max_increase =
                            cons.expressions[:max_storage_level_increase_intra_rep_period][row.id]
                        if row.period_block_start == 1 && !ismissing(initial_storage_level)
                            initial_storage_level_in_energy =
                                initial_storage_level *
                                available_energy_capacity[row.avail_energy_capacity_id]
                            @constraint(
                                model,
                                loss_coefficient * initial_storage_level_in_energy + max_increase ≤
                                max_storage_level_agg *
                                available_energy_capacity[row.avail_energy_capacity_id],
                                base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                            )
                        else
                            previous_level::JuMP.VariableRef = if row.period_block_start > 1
                                var_storage_level_inter_period.container[row.previous_id::Int]
                            else
                                var_storage_level_inter_period.container[row.cycle_id::Int]
                            end
                            @constraint(
                                model,
                                loss_coefficient * previous_level + max_increase ≤
                                max_storage_level_agg *
                                available_energy_capacity[row.avail_energy_capacity_id],
                                base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                            )
                        end
                    else
                        @constraint(
                            model,
                            var_storage_level_inter_period.container[row.storage_level_id] ≤
                            max_storage_level_agg *
                            available_energy_capacity[row.avail_energy_capacity_id],
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end

    # - Minimum inter-period storage level (4b or 6d-6e)
    let table_name = :min_storage_level_inter_period_limit,
        cons = constraints[table_name],
        indices = _append_storage_level_inter_period_bound_data_to_indices(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    conservative =
                        row.inter_period_storage_level_bounds == "inter_and_intra_rep_period"
                    min_storage_level_agg = if conservative
                        _profile_aggregate(
                            profiles.inter_period,
                            (row.min_storage_level_profile_name, row.milestone_year, row.scenario),
                            row.period_block_start:row.period_block_end,
                            maximum,
                            0.0,
                        )
                    else
                        _profile_aggregate(
                            profiles.inter_period,
                            (row.min_storage_level_profile_name, row.milestone_year, row.scenario),
                            row.period_block_start:row.period_block_end,
                            Statistics.mean,
                            0.0,
                        )
                    end
                    if conservative
                        initial_storage_level = row.initial_storage_level::Union{Float64,Missing}
                        loss_coefficient =
                            (
                                1.0 - (row.storage_loss_from_stored_energy::Float64)
                            )^(Int(row.duration_period_block))
                        max_decrease =
                            cons.expressions[:max_storage_level_decrease_intra_rep_period][row.id]
                        if row.period_block_start == 1 && !ismissing(initial_storage_level)
                            initial_storage_level_in_energy =
                                initial_storage_level *
                                available_energy_capacity[row.avail_energy_capacity_id]
                            @constraint(
                                model,
                                loss_coefficient * initial_storage_level_in_energy - max_decrease ≥
                                min_storage_level_agg *
                                available_energy_capacity[row.avail_energy_capacity_id],
                                base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                            )
                        else
                            previous_level::JuMP.VariableRef = if row.period_block_start > 1
                                var_storage_level_inter_period.container[row.previous_id::Int]
                            else
                                var_storage_level_inter_period.container[row.cycle_id::Int]
                            end
                            @constraint(
                                model,
                                loss_coefficient * previous_level - max_decrease ≥
                                min_storage_level_agg *
                                available_energy_capacity[row.avail_energy_capacity_id],
                                base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                            )
                        end
                    else
                        @constraint(
                            model,
                            var_storage_level_inter_period.container[row.storage_level_id] ≥
                            min_storage_level_agg *
                            available_energy_capacity[row.avail_energy_capacity_id],
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end

    # Cycling conditions:
    ## An explicit constraint is required because the initial level now depends on
    ## capacity expressions that can contain investment and decommission variables.
    model[:cycling_condition_intra_rep_period] = [
        @constraint(
            model,
            var_storage_level_intra_rep_period.container[row.last_id] ≥
            row.initial_storage_level * available_energy_capacity[row.avail_energy_capacity_id],
            base_name = "cycling_condition_intra_rep_period[$(row.asset),$(row.milestone_year),$(row.rep_period)]"
        ) for row in DuckDB.query(
            connection,
            "SELECT
                ARG_MAX(var.id, var.time_block_start) AS last_id,
                var.asset,
                var.milestone_year,
                var.rep_period,
                ANY_VALUE(asset_milestone.initial_storage_level) AS initial_storage_level,
                ANY_VALUE(expr_avail.id) AS avail_energy_capacity_id
            FROM var_storage_level_intra_rep_period AS var
            LEFT JOIN asset_milestone
                ON var.asset = asset_milestone.asset
                AND var.milestone_year = asset_milestone.milestone_year
            LEFT JOIN expr_available_energy_capacity_aggregated_vintage_method AS expr_avail
                ON var.asset = expr_avail.asset
                AND var.milestone_year = expr_avail.milestone_year
            WHERE asset_milestone.initial_storage_level > 0
            GROUP BY var.asset, var.milestone_year, var.rep_period
            ORDER BY var.asset, var.milestone_year, var.rep_period",
        )
    ]

    model[:cycling_condition_inter_period] = [
        @constraint(
            model,
            var_storage_level_inter_period.container[row.last_id] ≥
            row.initial_storage_level * available_energy_capacity[row.avail_energy_capacity_id],
            base_name = "cycling_condition_inter_period[$(row.asset),$(row.milestone_year),$(row.scenario)]"
        ) for row in DuckDB.query(
            connection,
            "SELECT
                ARG_MAX(var.id, var.period_block_start) AS last_id,
                var.asset,
                var.milestone_year,
                var.scenario,
                ANY_VALUE(asset_milestone.initial_storage_level) AS initial_storage_level,
                ANY_VALUE(expr_avail.id) AS avail_energy_capacity_id
            FROM var_storage_level_inter_period AS var
            LEFT JOIN asset_milestone
                ON var.asset = asset_milestone.asset
                AND var.milestone_year = asset_milestone.milestone_year
            LEFT JOIN expr_available_energy_capacity_aggregated_vintage_method AS expr_avail
                ON var.asset = expr_avail.asset
                AND var.milestone_year = expr_avail.milestone_year
            WHERE asset_milestone.initial_storage_level > 0
            GROUP BY var.asset, var.milestone_year, var.scenario
            ORDER BY var.asset, var.milestone_year, var.scenario",
        )
    ]

    ## intra-period constraints for seasonal storage
    let table_name = :accumulated_storage_intra_period, cons = constraints[table_name]
        var_accumulated_storage_level =
            variables[:accumulated_storage_level_intra_rep_period].container
        indices = _append_storage_data_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            :accumulated_storage_intra_period,
            [
                begin
                    profile_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.inflows_profile_name, row.milestone_year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        sum,
                        0.0,
                    )
                    storage_charging_efficiency = row.storage_charging_efficiency::Float64
                    storage_discharging_efficiency = row.storage_discharging_efficiency::Float64

                    if row.time_block_start == 1
                        @constraint(
                            model,
                            var_accumulated_storage_level[row.id] ==
                            profile_agg * row.storage_inflows +
                            storage_charging_efficiency * incoming_flow -
                            outgoing_flow / storage_discharging_efficiency,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    else
                        # Initial accumulated storage intra period is the previous level (a JuMP variable)
                        previous_accumulated_level::JuMP.VariableRef =
                            var_accumulated_storage_level[row.previous_id::Int]
                        computed_storage_loss_coef = 1.0
                        if row.storage_loss_from_stored_energy > 0.0
                            duration = row.time_block_end - row.time_block_start + 1
                            computed_storage_loss_coef =
                                (1 - row.storage_loss_from_stored_energy)^duration
                        end
                        @constraint(
                            model,
                            var_accumulated_storage_level[row.id] ==
                            computed_storage_loss_coef * previous_accumulated_level +
                            profile_agg * row.storage_inflows +
                            storage_charging_efficiency * incoming_flow -
                            outgoing_flow / storage_discharging_efficiency,
                            base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for (row, incoming_flow, outgoing_flow) in
                zip(indices, cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end
end

function _append_storage_data_to_indices(connection, table_name::Symbol)
    join_duration = ""
    select_duration = ""
    id_partition_columns, id_order_column = if table_name == :balance_storage_inter_period
        ("cons.asset, cons.milestone_year, cons.scenario", "cons.period_block_start")
    else
        ("cons.asset, cons.milestone_year, cons.rep_period", "cons.time_block_start")
    end
    select_neighbor_ids = """
    LAG(cons.id) OVER (
        PARTITION BY $id_partition_columns
        ORDER BY $id_order_column
    ) AS previous_id,
    LAST_VALUE(cons.id) OVER (
        PARTITION BY $id_partition_columns
        ORDER BY $id_order_column
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING -- frame expanding window to all rows, to avoid assuming ordering of ids
    ) AS cycle_id,
    """

    # Seasonal (inter-period) storage uses assets_timeframe_profiles (keyed by milestone_year
    # and scenario), while rep-period storage uses assets_profiles (keyed by commission_year).
    join_storage_level_profiles = if table_name == :balance_storage_inter_period
        """
        LEFT OUTER JOIN assets_timeframe_profiles AS max_storage_level_profile
            ON cons.asset = max_storage_level_profile.asset
            AND cons.milestone_year = max_storage_level_profile.milestone_year
            AND cons.scenario = max_storage_level_profile.scenario
            AND max_storage_level_profile.profile_type = 'max_storage_level'
        LEFT OUTER JOIN assets_timeframe_profiles AS min_storage_level_profile
            ON cons.asset = min_storage_level_profile.asset
            AND cons.milestone_year = min_storage_level_profile.milestone_year
            AND cons.scenario = min_storage_level_profile.scenario
            AND min_storage_level_profile.profile_type = 'min_storage_level'
        """
    else
        """
        LEFT OUTER JOIN assets_profiles AS max_storage_level_profile
            ON cons.asset = max_storage_level_profile.asset
            AND cons.milestone_year = max_storage_level_profile.commission_year
            AND max_storage_level_profile.profile_type = 'max_storage_level'
        LEFT OUTER JOIN assets_profiles AS min_storage_level_profile
            ON cons.asset = min_storage_level_profile.asset
            AND cons.milestone_year = min_storage_level_profile.commission_year
            AND min_storage_level_profile.profile_type = 'min_storage_level'
        """
    end

    if table_name == :balance_storage_inter_period
        DuckDB.query(
            connection,
            """
            CREATE OR REPLACE TEMP TABLE t_duration_inter_period AS
            SELECT
                cons.asset,
                cons.milestone_year,
                cons.scenario,
                cons.period_block_start,
                SUM(mapping.num_timesteps) AS duration_period_block
            FROM cons_balance_storage_inter_period AS cons
            LEFT JOIN timeframe_data AS mapping
                ON mapping.milestone_year = cons.milestone_year
                AND mapping.period BETWEEN cons.period_block_start AND cons.period_block_end
            GROUP BY cons.asset, cons.milestone_year, cons.scenario, cons.period_block_start
            """,
        )

        join_duration = """
        LEFT JOIN t_duration_inter_period AS duration
            ON cons.asset = duration.asset
            AND cons.milestone_year = duration.milestone_year
            AND cons.scenario = duration.scenario
            AND cons.period_block_start = duration.period_block_start
        """
        select_duration = "duration.duration_period_block,"
    end

    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            $select_duration
            $select_neighbor_ids
            asset.capacity,
            asset_commission.storage_loss_from_stored_energy,
            asset_commission.storage_charging_efficiency,
            asset_commission.storage_discharging_efficiency,
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
            AND cons.milestone_year = asset_commission.commission_year
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.milestone_year = asset_milestone.milestone_year
        LEFT JOIN expr_available_energy_capacity_aggregated_vintage_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.milestone_year = expr_avail.milestone_year
        LEFT OUTER JOIN assets_profiles AS inflows_profile
            ON cons.asset = inflows_profile.asset
            AND cons.milestone_year = inflows_profile.commission_year
            AND inflows_profile.profile_type = 'inflows'
        $join_storage_level_profiles
        $join_duration
        ORDER BY cons.id
        ",
    )
end

function _append_storage_level_intra_rep_period_bound_data_to_indices(
    connection::DuckDB.DB,
    table_name::Symbol,
)
    return DuckDB.query(
        connection,
        """
        SELECT
            cons.*,
            max_profile.profile_name AS max_storage_level_profile_name,
            min_profile.profile_name AS min_storage_level_profile_name,
            expr_avail.id AS avail_energy_capacity_id
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_energy_capacity_aggregated_vintage_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.milestone_year = expr_avail.milestone_year
        LEFT JOIN assets_profiles AS max_profile
            ON cons.asset = max_profile.asset
            AND cons.milestone_year = max_profile.commission_year
            AND max_profile.profile_type = 'max_storage_level'
        LEFT JOIN assets_profiles AS min_profile
            ON cons.asset = min_profile.asset
            AND cons.milestone_year = min_profile.commission_year
            AND min_profile.profile_type = 'min_storage_level'
        ORDER BY cons.id
        """,
    )
end

function _append_storage_level_inter_period_bound_data_to_indices(
    connection::DuckDB.DB,
    table_name::Symbol,
)
    return DuckDB.query(
        connection,
        """
        WITH
            variable_neighbors AS (
                SELECT
                    var.id,
                    LAG(var.id) OVER (
                        PARTITION BY var.asset, var.milestone_year, var.scenario
                        ORDER BY var.period_block_start
                    ) AS previous_id,
                    LAST_VALUE(var.id) OVER (
                        PARTITION BY var.asset, var.milestone_year, var.scenario
                        ORDER BY var.period_block_start
                        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                    ) AS cycle_id
                FROM var_storage_level_inter_period AS var
            ),
            durations AS (
                SELECT
                    cons.id,
                    SUM(timeframe.num_timesteps) AS duration_period_block
                FROM cons_$table_name AS cons
                LEFT JOIN timeframe_data AS timeframe
                    ON cons.milestone_year = timeframe.milestone_year
                    AND timeframe.period BETWEEN cons.period_block_start AND cons.period_block_end
                GROUP BY cons.id
            )
        SELECT
            cons.*,
            variable_neighbors.previous_id,
            variable_neighbors.cycle_id,
            durations.duration_period_block,
            asset_commission.storage_loss_from_stored_energy,
            asset_milestone.initial_storage_level,
            max_profile.profile_name AS max_storage_level_profile_name,
            min_profile.profile_name AS min_storage_level_profile_name,
            expr_avail.id AS avail_energy_capacity_id
        FROM cons_$table_name AS cons
        LEFT JOIN variable_neighbors ON cons.storage_level_id = variable_neighbors.id
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.milestone_year = asset_commission.commission_year
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.milestone_year = asset_milestone.milestone_year
        LEFT JOIN expr_available_energy_capacity_aggregated_vintage_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.milestone_year = expr_avail.milestone_year
        LEFT JOIN assets_timeframe_profiles AS max_profile
            ON cons.asset = max_profile.asset
            AND cons.milestone_year = max_profile.milestone_year
            AND cons.scenario = max_profile.scenario
            AND max_profile.profile_type = 'max_storage_level'
        LEFT JOIN assets_timeframe_profiles AS min_profile
            ON cons.asset = min_profile.asset
            AND cons.milestone_year = min_profile.milestone_year
            AND cons.scenario = min_profile.scenario
            AND min_profile.profile_type = 'min_storage_level'
        LEFT JOIN durations ON cons.id = durations.id
        ORDER BY cons.id
        """,
    )
end
