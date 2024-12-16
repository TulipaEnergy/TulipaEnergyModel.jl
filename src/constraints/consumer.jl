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
                # On demand computation of the mean
                demand_array = Float64[
                    row.value for row in DuckDB.query(
                        connection,
                        "SELECT profile.value
                        FROM profiles_rep_periods AS profile
                        LEFT JOIN assets_profiles
                            ON assets_profiles.profile_name = profile.profile_name
                            AND assets_profiles.commission_year = profile.year
                        WHERE profile_type = 'demand'
                            AND assets_profiles.asset='$(row.asset)'
                            AND profile.year=$(row.year)
                            AND profile.rep_period=$(row.rep_period)
                            AND profile.timestep >= $(row.time_block_start)
                            AND profile.timestep <= $(row.time_block_end)
                        ",
                    )
                ]
                demand_agg = length(demand_array) > 0 ? Statistics.mean(demand_array) : 1.0
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

function _create_consumer_table(connection, cons::String)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset.type,
            asset.consumer_balance_sense,
            asset_milestone.peak_demand,
        FROM $cons AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.year = asset_milestone.milestone_year
        ORDER BY cons.index -- order is important
        ",
    )
end
