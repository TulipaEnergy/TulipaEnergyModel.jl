export add_flow_variables!, add_vintage_flow_variables!

"""
    add_flow_variables!(connection, model, variables)

Adds flow variables to the optimization `model` based on data from the `variables`.
The flow variables are created using the `@variable` macro for each row in the `:flow` table.

"""
function add_flow_variables!(connection, model, variables)
    # Unpacking the variable indices
    indices = _create_flow_table(connection)

    lower_bound(row) =
        if row.is_transport || row.investment_method == "semi-compact"
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
            asset.investment_method,
        FROM var_flow
        LEFT JOIN flow
            ON flow.from_asset = var_flow.from_asset
            AND flow.to_asset = var_flow.to_asset
        LEFT JOIN asset
            on asset.asset = var_flow.from_asset
        ORDER BY var_flow.id
        ",
    )
end

"""
    add_vintage_flow_variables!(connection, model, variables)

Adds vintage flow variables to the optimization `model` based on data from the `variables`.
The vintage flow variables are created using the `@variable` macro for each row in the `:vintage_flow` table.

"""

function add_vintage_flow_variables!(connection, model, variables)
    # Unpacking the variable indices
    indices = _create_vintage_flow_table(connection)

    lower_bound(row) =
        if row.is_transport
            -Inf
        else
            0.0
        end

    variables[:vintage_flow].container = [
        @variable(
            model,
            lower_bound = lower_bound(row),
            base_name = "vintage_flow[($(row.from_asset),$(row.to_asset)),$(row.milestone_year),$(row.commission_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in indices
    ]

    return
end

function _create_vintage_flow_table(connection)
    return DuckDB.query(
        connection,
        "SELECT
            var_vintage_flow.*,
            flow.is_transport,
        FROM var_vintage_flow
        LEFT JOIN flow
            ON flow.from_asset = var_vintage_flow.from_asset
            AND flow.to_asset = var_vintage_flow.to_asset
        ORDER BY var_vintage_flow.id
        ",
    )
end
