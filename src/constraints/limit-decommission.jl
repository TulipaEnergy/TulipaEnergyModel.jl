"""
    _get_limit_decommission_specifications()

Returns the specifications of the decommission limits, one per decommission variable family
(asset units, storage energy units, transport flow units).

Each specification holds the constraint table name, the investment and decommission variable
names, and the columns that identify an asset or a flow.
"""
function _get_limit_decommission_specifications()
    return (
        (
            table_name = :limit_decommission_assets,
            var_investment = :assets_investment,
            var_decommission = :assets_decommission,
            key_columns = ("asset",),
        ),
        (
            table_name = :limit_decommission_storage_energy,
            var_investment = :assets_investment_energy,
            var_decommission = :assets_decommission_energy,
            key_columns = ("asset",),
        ),
        (
            table_name = :limit_decommission_flows,
            var_investment = :flows_investment,
            var_decommission = :flows_decommission,
            key_columns = ("from_asset", "to_asset"),
        ),
    )
end

"""
    add_limit_decommission_constraints!(connection, model, variables, constraints)

Adds the upper bounds on the decommission variables for the asset units, the storage energy units,
and the transport flow units, for every vintage method.

The model only decommissions units that it invested in: the decommission variables are indexed by
the milestone year of the decision and by the commission year of the vintage, and the sum of the
decommissions of a vintage is bounded by the investment of that vintage. Existing units (the
initial units of each milestone year) are data given by the user and are never decommissioned.
"""
function add_limit_decommission_constraints!(connection, model, variables, constraints)
    for spec in _get_limit_decommission_specifications()
        var_inv = variables[spec.var_investment].container
        var_dec = variables[spec.var_decommission].container

        let table_name = spec.table_name, cons = constraints[table_name]
            indices = _append_decommission_ids_to_indices(connection, table_name, spec)
            attach_constraint!(
                model,
                cons,
                table_name,
                [
                    @constraint(
                        model,
                        var_inv[row.var_investment_id] -
                        sum(var_dec[id] for id in row.var_decommission_ids) ≥ 0,
                        base_name = "$table_name[$(_join_keys(row, spec.key_columns)),$(row.commission_year)]"
                    ) for row in indices
                ],
            )
        end
    end

    return
end

"""
    _join_keys(row, key_columns)

Returns the values of `key_columns` in `row` joined by commas, for the constraint names.
"""
function _join_keys(row, key_columns)
    return join((string(getproperty(row, Symbol(column))) for column in key_columns), ",")
end

"""
    _join_on_keys(left, right, key_columns)

Returns the SQL join condition equating `key_columns` between the aliases `left` and `right`.
"""
function _join_on_keys(left, right, key_columns)
    return join(("$left.$column = $right.$column" for column in key_columns), " AND ")
end

"""
    _append_decommission_ids_to_indices(connection, table_name, spec)

Appends, for each row of `cons_\$table_name`, the id of the investment variable of the vintage and the ids of
all the decommission variables of that vintage.
"""
function _append_decommission_ids_to_indices(connection, table_name, spec)
    cons_columns = join(("cons.$column" for column in spec.key_columns), ", ")
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            $cons_columns,
            cons.commission_year,
            ANY_VALUE(var_inv.id) AS var_investment_id,
            ARRAY_AGG(var_dec.id ORDER BY var_dec.id) AS var_decommission_ids,
        FROM cons_$table_name AS cons
        INNER JOIN var_$(spec.var_investment) AS var_inv
            ON $(_join_on_keys("var_inv", "cons", spec.key_columns))
            AND var_inv.milestone_year = cons.commission_year
        INNER JOIN var_$(spec.var_decommission) AS var_dec
            ON $(_join_on_keys("var_dec", "cons", spec.key_columns))
            AND var_dec.commission_year = cons.commission_year
        GROUP BY cons.id, $cons_columns, cons.commission_year
        ORDER BY cons.id
        ",
    )
end
