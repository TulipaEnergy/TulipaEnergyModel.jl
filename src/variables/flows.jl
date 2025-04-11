export add_flow_variables!

"""
    add_flow_variables!(connection, model, variables)

Adds flow variables to the optimization `model` based on data from the `variables`.
The flow variables are created using the `@variable` macro for each row in the `:flows` table.

"""
function add_flow_variables!(connection, model, variables)
    # Unpacking the variable indices
    indices = _create_flow_table(connection)

    lower_bound(row) =
        if row.is_transport
            -Inf
        else
            0.0
        end

    variables[:flow].container = [
        @variable(
            model,
            lower_bound = lower_bound(row),
            base_name = "flow[($(row.from_asset),$(row.to_asset)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in indices
    ]

    return
end

function _create_flow_table(connection)
    return DuckDB.query(
        connection,
        "SELECT
            var_flow.*,
            flow.is_transport,
        FROM variables.flow as var_flow
        LEFT JOIN input.flow as flow
            ON flow.from_asset = var_flow.from_asset
            AND flow.to_asset = var_flow.to_asset
        ORDER BY var_flow.id
        ",
    )
end
