"""
    add_demand_response_constraints!(connection, model, variables, constraints, profiles)

Adds the demand response constraints for consumer assets using the
`shifting_with_recovery` method:

  - Upper bounds on the upward (`d⁺`) and downward (`d⁻`) demand deviations,
    capping each instantaneous deviation to a fraction `β` of the baseline
    demand `D⁰` (`dr_max_shift_fraction`).
  - Window recovery constraints enforcing that the net shifted energy over each
    recovery window is zero: `∑_{b∈w} (d⁺_b − d⁻_b) · Δ_b = 0`.
"""
function add_demand_response_constraints!(connection, model, variables, constraints, profiles)
    d_increase = variables[:dr_demand_increase].container
    d_decrease = variables[:dr_demand_decrease].container

    # The increase and decrease variable index tables are built from the same
    # filtered rows in the same order, so their ids coincide for a given block.

    # Cap each deviation to β · D⁰ using variable upper bounds.
    for row in DuckDB.query(
        connection,
        "SELECT
            dr.id,
            dr.milestone_year,
            dr.rep_period,
            dr.time_block_start,
            dr.time_block_end,
            asset_milestone.peak_demand,
            asset_milestone.dr_max_shift_fraction,
            assets_profiles.profile_name,
        FROM var_dr_demand_increase AS dr
        LEFT JOIN asset_milestone
            ON dr.asset = asset_milestone.asset
            AND dr.milestone_year = asset_milestone.milestone_year
        LEFT OUTER JOIN assets_profiles
            ON dr.asset = assets_profiles.asset
            AND dr.milestone_year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'demand'
        ORDER BY dr.id
        ",
    )
        demand_agg = _profile_aggregate(
            profiles.rep_period,
            (row.profile_name, row.milestone_year, row.rep_period),
            row.time_block_start:row.time_block_end,
            Statistics.mean,
            1.0,
        )
        max_deviation = row.dr_max_shift_fraction * demand_agg * row.peak_demand
        JuMP.set_upper_bound(d_increase[row.id], max_deviation)
        JuMP.set_upper_bound(d_decrease[row.id], max_deviation)
    end

    # Window recovery: net shifted energy over each window must be zero.
    let cons = constraints[:dr_window_balance]
        attach_constraint!(
            model,
            cons,
            :dr_window_balance,
            [
                @constraint(
                    model,
                    sum(
                        (d_increase[var_id] - d_decrease[var_id]) * duration for
                        (var_id, duration) in zip(row.var_ids, row.durations)
                    ) == 0,
                    base_name = "dr_window_balance[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in DuckDB.query(
                    connection,
                    "SELECT
                        cons.id,
                        cons.asset,
                        cons.milestone_year,
                        cons.rep_period,
                        cons.time_block_start,
                        cons.time_block_end,
                        array_agg(dr.id ORDER BY dr.time_block_start) AS var_ids,
                        array_agg(
                            dr.time_block_end - dr.time_block_start + 1
                            ORDER BY dr.time_block_start
                        ) AS durations,
                    FROM cons_dr_window_balance AS cons
                    LEFT JOIN var_dr_demand_increase AS dr
                        ON cons.asset = dr.asset
                        AND cons.milestone_year = dr.milestone_year
                        AND cons.rep_period = dr.rep_period
                        AND dr.time_block_start >= cons.time_block_start
                        AND dr.time_block_end <= cons.time_block_end
                    GROUP BY
                        cons.id,
                        cons.asset,
                        cons.milestone_year,
                        cons.rep_period,
                        cons.time_block_start,
                        cons.time_block_end
                    ORDER BY cons.id
                    ",
                )
            ],
        )
    end

    return
end
