export add_flows_relationships_constraints!

"""
    add_flows_relationships_constraints!(connection, model, variables, constraints)

Adds the flows relationships constraints to the model.
"""
function add_flows_relationships_constraints!(connection, model, variables, constraints)
    cons = constraints[:flows_relationships]
    flows = variables[:flow]

    grouped_indices_flow_1 =
        _get_flow_aggregated_indices(connection, "flow_1_from_asset", "flow_1_to_asset")
    grouped_indices_flow_2 =
        _get_flow_aggregated_indices(connection, "flow_2_from_asset", "flow_2_to_asset")

    # Expressions used by flows relationships
    attach_expression!(
        cons,
        :flow_1,
        [
            begin
                @expression(model, sum(flows.container[id] for id in row.matching_ids))
            end for row in grouped_indices_flow_1
        ],
    )
    attach_expression!(
        cons,
        :flow_2,
        [
            begin
                @expression(model, sum(flows.container[id] for id in row.matching_ids))
            end for row in grouped_indices_flow_2
        ],
    )

    # - Constraints between two flows (using the lowest temporal resolution)
    attach_constraint!(
        model,
        cons,
        :balance_consumer,
        [
            begin
                constraint_sense = if row.sense == "=="
                    MathOptInterface.EqualTo(0.0)
                elseif row.sense == ">="
                    MathOptInterface.GreaterThan(0.0)
                else
                    MathOptInterface.LessThan(0.0)
                end
                @constraint(
                    model,
                    flow_1 - row.constant - row.ratio * flow_2 in constraint_sense,
                    base_name = "flows_relationships[$(row.flow_1_from_asset)_$(row.flow_1_to_asset),
                                                     $(row.flow_2_from_asset)_$(row.flow_2_to_asset),
                                                     $(row.year),
                                                     $(row.rep_period),
                                                     $(row.time_block_start):$(row.time_block_end)
                                                     ]"
                )
            end for (row, flow_1, flow_2) in
            zip(cons.indices, cons.expressions[:flow_1], cons.expressions[:flow_2])
        ],
    )

    return
end

function _get_flow_aggregated_indices(connection, from_asset::String, to_asset::String)
    return DuckDB.query(
        connection,
        "SELECT
             indices.id,
             COALESCE(ARRAY_AGG(flow.id), []::BIGINT[]) AS matching_ids
         FROM cons_flows_relationships AS indices
         LEFT JOIN var_flow AS flow
             ON  indices.$(from_asset) = flow.from_asset
             AND indices.$(to_asset) = flow.to_asset
             AND indices.year = flow.year
             AND indices.rep_period = flow.rep_period
             AND flow.time_block_start
                    BETWEEN indices.time_block_start AND indices.time_block_end
         GROUP BY
             indices.id
         ORDER BY
             indices.id;
        ",
    )
end
