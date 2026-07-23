"""
    add_consumer_constraints!(connection, model, constraints, profiles)

Adds the consumer asset constraints to the model.
"""
function add_consumer_constraints!(connection, model, variables, constraints, profiles)
    cons = constraints[:balance_consumer]

    table = _create_consumer_table(connection)

    # - Balance constraint (using the lowest temporal resolution)
    attach_constraint!(
        model,
        cons,
        :balance_consumer,
        [
            begin
                consumer_balance_sense = if row.consumer_balance_sense == "=="
                    MathOptInterface.EqualTo(0.0)
                elseif row.consumer_balance_sense == ">="
                    MathOptInterface.GreaterThan(0.0)
                else
                    MathOptInterface.LessThan(0.0)
                end
                # Demand response shifts the effective demand up (d⁺) or down (d⁻).
                dr_term = JuMP.AffExpr(0.0)
                if !ismissing(row.dr_increase_var_id)
                    JuMP.add_to_expression!(
                        dr_term,
                        variables[:dr_demand_increase].container[row.dr_increase_var_id],
                    )
                    JuMP.add_to_expression!(
                        dr_term,
                        -1.0,
                        variables[:dr_demand_decrease].container[row.dr_decrease_var_id],
                    )
                end
                if !ismissing(row.loop_var_id)
                    var = variables[:flow].container[row.loop_var_id]
                    @constraint(
                        model,
                        incoming_flow - outgoing_flow - var * row.peak_demand - dr_term in
                        consumer_balance_sense,
                        base_name = "consumer_balance[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                else
                    # On demand computation of the mean
                    demand_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.milestone_year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @constraint(
                        model,
                        incoming_flow - outgoing_flow - demand_agg * row.peak_demand - dr_term in
                        consumer_balance_sense,
                        base_name = "consumer_balance[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end
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
        milestone_year, rep_period) don't have a profile for the given profile_type.

        If we use a WHERE condition, all combination with all the profile_type
        would be created, and only after that it would be filtered (which would
        probably leave the table with a different number of rows, and thus
        impossible to match the constraints table.
    =#
    return DuckDB.query(
        connection,
        "WITH cte_loop AS (
            SELECT
                cons.id AS cons_id,
                var.id AS var_id,
            FROM cons_balance_consumer AS cons
            LEFT JOIN var_flow AS var
                ON cons.asset = var.from_asset
                AND cons.asset = var.to_asset
                AND cons.milestone_year = var.milestone_year
                AND cons.rep_period = var.rep_period
                AND cons.time_block_start = var.time_block_start -- TODO: This is a simplification ignoring different time resolution
                AND cons.time_block_end = var.time_block_end
        )
        SELECT
            cons.*,
            asset.type,
            asset.consumer_balance_sense,
            asset.demand_response_method,
            asset_milestone.peak_demand,
            assets_profiles.profile_name,
            cte_loop.var_id AS loop_var_id,
            dr_inc.id AS dr_increase_var_id,
            dr_dec.id AS dr_decrease_var_id,
        FROM cons_balance_consumer AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_milestone
            ON cons.asset = asset_milestone.asset
            AND cons.milestone_year = asset_milestone.milestone_year
        LEFT JOIN cte_loop
            ON cons.id = cte_loop.cons_id
        LEFT JOIN var_dr_demand_increase AS dr_inc
            ON cons.asset = dr_inc.asset
            AND cons.milestone_year = dr_inc.milestone_year
            AND cons.rep_period = dr_inc.rep_period
            AND cons.time_block_start = dr_inc.time_block_start
            AND cons.time_block_end = dr_inc.time_block_end
        LEFT JOIN var_dr_demand_decrease AS dr_dec
            ON cons.asset = dr_dec.asset
            AND cons.milestone_year = dr_dec.milestone_year
            AND cons.rep_period = dr_dec.rep_period
            AND cons.time_block_start = dr_dec.time_block_start
            AND cons.time_block_end = dr_dec.time_block_end
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.milestone_year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'demand' -- This must be a ON condition not a where (note 1)
        ORDER BY cons.id -- order is important
        ",
    )
end
