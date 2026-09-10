"""
    add_limit_decommission_aggregated_method_constraints!(connection, model, variables, constraints)

Adds the upper bounds on the decommission variables of assets that use the aggregated vintage method.

The decommission variable of an aggregated asset is split by the commission year of the decommissioned units:

- rows with `commission_year = milestone_year` decommission existing (initial) units, and are bounded by the
  initial units of the asset at every milestone year within the technical lifetime of the decision;
- rows with `commission_year < milestone_year` decommission units invested in `commission_year`, and are bounded by
  the investment of that vintage.

The compact vintage methods have their own lower bound on the available units per vintage, see
[`add_limit_decommission_compact_method_constraints!`](@ref).
"""
function add_limit_decommission_aggregated_method_constraints!(
    connection,
    model,
    variables,
    constraints,
)
    var_inv = variables[:assets_investment].container
    var_dec = variables[:assets_decommission].container

    let table_name = :limit_decommission_initial_units_aggregated_vintage_method,
        cons = constraints[table_name]

        indices = _append_decommission_of_initial_units_ids_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    row.initial_units - sum(var_dec[id] for id in row.var_decommission_ids) ≥ 0,
                    base_name = "$table_name[$(row.asset),$(row.milestone_year)]"
                ) for row in indices
            ],
        )
    end

    let table_name = :limit_decommission_invested_units_aggregated_vintage_method,
        cons = constraints[table_name]

        indices = _append_decommission_of_invested_units_ids_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    var_inv[row.var_investment_id] -
                    sum(var_dec[id] for id in row.var_decommission_ids) ≥ 0,
                    base_name = "$table_name[$(row.asset),$(row.commission_year)]"
                ) for row in indices
            ],
        )
    end

    return
end

"""
    _append_decommission_of_initial_units_ids_to_indices(connection, table_name)

Appends, for each row of `cons_\$table_name`, the ids of the decommission variables of existing units
taken at a milestone year within the technical lifetime window that ends at the row's milestone year.
"""
function _append_decommission_of_initial_units_ids_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            cons.asset,
            cons.milestone_year,
            cons.initial_units,
            ARRAY_AGG(var_dec.id ORDER BY var_dec.id) AS var_decommission_ids,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        INNER JOIN var_assets_decommission AS var_dec
            ON var_dec.asset = cons.asset
            AND var_dec.commission_year = var_dec.milestone_year
            AND var_dec.milestone_year <= cons.milestone_year
            AND var_dec.milestone_year + asset.technical_lifetime - 1 >= cons.milestone_year
        GROUP BY cons.id, cons.asset, cons.milestone_year, cons.initial_units
        ORDER BY cons.id
        ",
    )
end

"""
    _append_decommission_of_invested_units_ids_to_indices(connection, table_name)

Appends, for each row of `cons_\$table_name`, the id of the investment variable of the vintage and the ids of
all the decommission variables of that vintage.
"""
function _append_decommission_of_invested_units_ids_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            cons.asset,
            cons.commission_year,
            ANY_VALUE(var_inv.id) AS var_investment_id,
            ARRAY_AGG(var_dec.id ORDER BY var_dec.id) AS var_decommission_ids,
        FROM cons_$table_name AS cons
        INNER JOIN var_assets_investment AS var_inv
            ON var_inv.asset = cons.asset
            AND var_inv.milestone_year = cons.commission_year
        INNER JOIN var_assets_decommission AS var_dec
            ON var_dec.asset = cons.asset
            AND var_dec.commission_year = cons.commission_year
            AND var_dec.commission_year < var_dec.milestone_year
        GROUP BY cons.id, cons.asset, cons.commission_year
        ORDER BY cons.id
        ",
    )
end
