export add_consumer_constraints!

"""
add_consumer_constraints!(model,
                          graph,
                          dataframes,
                          Ac,
                          incoming_flow_highest_in_out_resolution,
                          outgoing_flow_highest_in_out_resolution,
                          )

Adds the consumer asset constraints to the model.
"""
function add_consumer_constraints!(connection, model, constraints)
    cons = constraints[:balance_consumer]

    # TODO: Store the name of the table in the TulipaConstraint
    table = _create_consumer_table(connection, "cons_balance_consumer")

    # - Balance constraint (using the lowest temporal resolution)
    attach_constraint!(
        model,
        cons,
        :consumer_balance,
        [
            begin
                consumer_balance_sense = if ismissing(row.consumer_balance_sense)
                    MathOptInterface.EqualTo(0.0)
                else
                    MathOptInterface.GreaterThan(0.0)
                end
                @constraint(
                    model,
                    incoming_flow - outgoing_flow - row.demand_agg * row.peak_demand in
                    consumer_balance_sense,
                    base_name = "consumer_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                )
            end for (row, incoming_flow, outgoing_flow) in
            zip(table, cons.expressions[:incoming], cons.expressions[:outgoing])
        ],
    )

    return
end

function _create_consumer_table(connection, cons::String)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            ANY_VALUE(asset.type) AS type,
            ANY_VALUE(asset.consumer_balance_sense) AS consumer_balance_sense,
            ANY_VALUE(asset_milestone.peak_demand) AS peak_demand,
            COALESCE(MEAN(profile.value), 1) AS demand_agg
        FROM $cons AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.year = asset_milestone.milestone_year
        LEFT JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'demand'
        LEFT JOIN profiles_rep_periods AS profile
            ON profile.profile_name = assets_profiles.profile_name
            AND cons.year = profile.year
            AND cons.rep_period = profile.rep_period
            AND cons.time_block_start <= profile.timestep
            AND profile.timestep <= cons.time_block_end
        GROUP BY cons.*
        ORDER BY cons.index -- order is important
        ",
    )
end
