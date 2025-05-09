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
        if row.from_asset_type in ("producer", "conversion", "storage") ||
           row.to_asset_type in ("conversion", "storage")
            0.0
        else
            -Inf
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
            flow.*,
            from_asset.type AS from_asset_type,
            to_asset.type AS to_asset_type,
        FROM variables.flow AS flow
        LEFT JOIN input.asset AS from_asset
            ON flow.from_asset = from_asset.asset
        LEFT JOIN input.asset AS to_asset
            ON flow.to_asset = to_asset.asset
        ORDER BY flow.id
        ",
    )
end
