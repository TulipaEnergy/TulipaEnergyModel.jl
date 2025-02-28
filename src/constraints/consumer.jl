export add_consumer_constraints!

"""
    add_consumer_constraints!(connection, model, constraints, profiles)

Adds the consumer asset constraints to the model.
"""
function add_consumer_constraints!(connection, model, constraints, profiles)
    cons = constraints[:balance_consumer]

    table = _create_consumer_table(connection)

    # - Balance constraint (using the lowest temporal resolution)
    attach_constraint!(
        model,
        cons,
        :balance_consumer,
        [
            begin
                consumer_balance_sense = if ismissing(row.consumer_balance_sense)
                    MathOptInterface.EqualTo(0.0)
                else
                    MathOptInterface.GreaterThan(0.0)
                end
                # On demand computation of the mean
                demand_agg = _profile_aggregate(
                    profiles.rep_period,
                    (row.profile_name, row.year, row.rep_period),
                    row.time_block_start:row.time_block_end,
                    Statistics.mean,
                    1.0,
                )
                @constraint(
                    model,
                    incoming_flow - outgoing_flow - demand_agg * row.peak_demand in
                    consumer_balance_sense,
                    base_name = "consumer_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                )
            end for (row, incoming_flow, outgoing_flow) in
            zip(table, cons.expressions[:incoming], cons.expressions[:outgoing])
        ],
    )

    return
end

function _create_consumer_table(connection)
    #=
        In the query below, the "filtering" by profile_type = 'demand' must
        happen at the join clause, i.e., in the ON ... AND ... list. This is
        necessary because we are using an OUTER join with the result, because
        we want to propagate the information that some combinations of (asset,
        year, rep_period) don't have a profile for the given profile_type.

        If we use a WHERE condition, all combination with all the profile_type
        would be created, and only after that it would be filtered (which would
        probably leave the table with a different number of rows, and thus
        impossible to match the constraints table.
    =#
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset.type,
            asset.consumer_balance_sense,
            asset_milestone.peak_demand,
            assets_profiles.profile_name,
        FROM cons_balance_consumer AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.year = asset_milestone.milestone_year
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'demand' -- This must be a ON condition not a where (note 1)
        ORDER BY cons.id -- order is important
        ",
    )
end
