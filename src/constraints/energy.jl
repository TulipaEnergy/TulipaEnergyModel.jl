export add_energy_constraints!

"""
    add_energy_constraints!(connection, model, constraints, profiles)

Adds the energy constraints for assets within the period blocks of the timeframe (over_clustered_year) to the model.
"""
function add_energy_constraints!(connection, model, constraints, profiles)
    ## OVER-CLUSTERED-YEAR CONSTRAINTS (between representative periods)

    let table_name = :max_energy_over_clustered_year, cons = constraints[table_name]
        indices = _append_energy_data_to_indices(connection, table_name, :max)
        # - Maximum outgoing energy within each period block
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    max_energy_agg = _profile_aggregate(
                        profiles.over_clustered_year,
                        (row.profile_name, row.year),
                        row.period_block_start:row.period_block_end,
                        sum,
                        1.0,
                    )
                    @constraint(
                        model,
                        outgoing_flow ≤ max_energy_agg * row.max_energy_timeframe_partition,
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                    )
                end for (row, outgoing_flow) in zip(indices, cons.expressions[:outgoing])
            ],
        )
    end

    let table_name = :min_energy_over_clustered_year, cons = constraints[table_name]
        indices = _append_energy_data_to_indices(connection, table_name, :min)
        # - Minimum outgoing energy within each period block
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    min_energy_agg = _profile_aggregate(
                        profiles.over_clustered_year,
                        (row.profile_name, row.year),
                        row.period_block_start:row.period_block_end,
                        sum,
                        1.0,
                    )
                    @constraint(
                        model,
                        outgoing_flow ≥ min_energy_agg * row.min_energy_timeframe_partition,
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                    )
                end for (row, outgoing_flow) in zip(indices, cons.expressions[:outgoing])
            ],
        )
    end

    return
end

function _append_energy_data_to_indices(connection, table_name, min_or_max)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset_milestone.$(min_or_max)_energy_timeframe_partition,
            assets_timeframe_profiles.profile_name
        FROM cons_$table_name AS cons
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.year = asset_milestone.milestone_year
        LEFT OUTER JOIN assets_timeframe_profiles
            ON cons.asset = assets_timeframe_profiles.asset
            AND cons.year = assets_timeframe_profiles.commission_year
            AND assets_timeframe_profiles.profile_type = '$(min_or_max)_energy'
        ORDER BY cons.id
        ",
    )
end
