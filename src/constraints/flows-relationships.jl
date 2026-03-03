export add_flows_relationships_constraints!

"""
    add_flows_relationships_constraints!(connection, model, variables, constraints)

Adds the flows relationships constraints to the model.
"""
function add_flows_relationships_constraints!(connection, model, variables, constraints)
    cons = constraints[:flows_relationships]
    flows = variables[:flow]

    # get the indices of the flows that are used in the constraints from flow_1 and flow_2
    grouped_indices_flow_1 =
        _get_flow_aggregated_indices(connection, "flow_1_from_asset", "flow_1_to_asset")
    grouped_indices_flow_2 =
        _get_flow_aggregated_indices(connection, "flow_2_from_asset", "flow_2_to_asset")

    # Expressions used by flows relationships
    for (expression_name, grouped_indices) in
        zip((:flow_1, :flow_2), (grouped_indices_flow_1, grouped_indices_flow_2))
        attach_expression!(
            cons,
            expression_name,
            JuMP.AffExpr[
                @expression(
                    model,
                    sum(
                        row.duration[i] * flows.container[id] for
                        (i, id) in enumerate(row.matching_ids)
                    )
                ) for row in grouped_indices
            ],
        )
    end

    # - Constraints between two flows (using the lowest temporal resolution)
    attach_constraint!(
        model,
        cons,
        :flows_relationships,
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
                    base_name = "flows_relationships[$(row.asset), $(row.milestone_year), $(row.rep_period), $(row.time_block_start):$(row.time_block_end)]"
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
             COALESCE(ARRAY_AGG(flow.id), []::BIGINT[]) AS matching_ids,
             COALESCE(ARRAY_AGG(LEAST(indices.time_block_end, flow.time_block_end) -
                                GREATEST(indices.time_block_start, flow.time_block_start) +
                                1), []::BIGINT[]) AS duration
         FROM cons_flows_relationships AS indices
         LEFT JOIN var_flow AS flow
             ON  indices.$(from_asset) = flow.from_asset
             AND indices.$(to_asset) = flow.to_asset
             AND indices.milestone_year = flow.milestone_year
             AND indices.rep_period = flow.rep_period
             AND flow.time_block_start <= indices.time_block_end
             AND flow.time_block_end >= indices.time_block_start
         GROUP BY
             indices.id
         ORDER BY
             indices.id;
        ",
    )
end
