"""
    _get_limit_decommission_aggregated_method_specifications()

Returns the specifications of the decommission limits of the aggregated vintage method, one per
decommission variable family (asset units, storage energy units, transport flow units).

Each specification holds the constraint table names, the variable names, the table that holds the
technical lifetime, the columns that identify an asset or a flow, and the initial units columns
with the suffix of the constraint name built from each of them.
"""
function _get_limit_decommission_aggregated_method_specifications()
    return (
        (
            initial_table = :limit_decommission_initial_units_aggregated_vintage_method,
            invested_table = :limit_decommission_invested_units_aggregated_vintage_method,
            var_investment = :assets_investment,
            var_decommission = :assets_decommission,
            lifetime_table = "asset",
            key_columns = ("asset",),
            initial_columns = (("", :initial_units),),
        ),
        (
            initial_table = :limit_decommission_energy_initial_units_aggregated_vintage_method,
            invested_table = :limit_decommission_energy_invested_units_aggregated_vintage_method,
            var_investment = :assets_investment_energy,
            var_decommission = :assets_decommission_energy,
            lifetime_table = "asset",
            key_columns = ("asset",),
            initial_columns = (("", :initial_storage_units),),
        ),
        (
            initial_table = :limit_decommission_flows_initial_units_aggregated_vintage_method,
            invested_table = :limit_decommission_flows_invested_units_aggregated_vintage_method,
            var_investment = :flows_investment,
            var_decommission = :flows_decommission,
            lifetime_table = "flow",
            key_columns = ("from_asset", "to_asset"),
            initial_columns = (
                ("_export", :initial_export_units),
                ("_import", :initial_import_units),
            ),
        ),
    )
end

"""
    add_limit_decommission_aggregated_method_constraints!(connection, model, variables, constraints)

Adds the upper bounds on the decommission variables of the aggregated vintage method, for the asset
units, the storage energy units, and the transport flow units.

The decommission variables of the aggregated method are split by the commission year of the
decommissioned units:

- rows with `commission_year = milestone_year` decommission existing (initial) units, and are bounded by the
  initial units at every milestone year within the technical lifetime of the decision;
- rows with `commission_year < milestone_year` decommission units invested in `commission_year`, and are bounded by
  the investment of that vintage.

For transport flows the same decommission variable reduces both the export and the import units, so the
existing units limit is added once per direction.

The compact vintage methods have their own lower bound on the available units per vintage, see
[`add_limit_decommission_compact_method_constraints!`](@ref).
"""
function add_limit_decommission_aggregated_method_constraints!(
    connection,
    model,
    variables,
    constraints,
)
    for spec in _get_limit_decommission_aggregated_method_specifications()
        var_inv = variables[spec.var_investment].container
        var_dec = variables[spec.var_decommission].container

        let table_name = spec.initial_table, cons = constraints[table_name]
            indices =
                _append_decommission_of_initial_units_ids_to_indices(connection, table_name, spec)
            for (suffix, initial_column) in spec.initial_columns
                attach_constraint!(
                    model,
                    cons,
                    Symbol(table_name, suffix),
                    [
                        @constraint(
                            model,
                            getproperty(row, initial_column) -
                            sum(var_dec[id] for id in row.var_decommission_ids) ≥ 0,
                            base_name = "$table_name$suffix[$(_join_keys(row, spec.key_columns)),$(row.milestone_year)]"
                        ) for row in indices
                    ],
                )
            end
        end

        let table_name = spec.invested_table, cons = constraints[table_name]
            indices =
                _append_decommission_of_invested_units_ids_to_indices(connection, table_name, spec)
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
    _append_decommission_of_initial_units_ids_to_indices(connection, table_name, spec)

Appends, for each row of `cons_\$table_name`, the ids of the decommission variables of existing units
taken at a milestone year within the technical lifetime window that ends at the row's milestone year.
"""
function _append_decommission_of_initial_units_ids_to_indices(connection, table_name, spec)
    cons_columns = join(
        vcat(
            ["cons.$column" for column in spec.key_columns],
            ["cons.$column" for (_, column) in spec.initial_columns],
        ),
        ", ",
    )
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            $cons_columns,
            cons.milestone_year,
            ARRAY_AGG(var_dec.id ORDER BY var_dec.id) AS var_decommission_ids,
        FROM cons_$table_name AS cons
        LEFT JOIN $(spec.lifetime_table) AS lifetime
            ON $(_join_on_keys("cons", "lifetime", spec.key_columns))
        INNER JOIN var_$(spec.var_decommission) AS var_dec
            ON $(_join_on_keys("var_dec", "cons", spec.key_columns))
            AND var_dec.commission_year = var_dec.milestone_year
            AND var_dec.milestone_year <= cons.milestone_year
            AND var_dec.milestone_year + lifetime.technical_lifetime - 1 >= cons.milestone_year
        GROUP BY cons.id, $cons_columns, cons.milestone_year
        ORDER BY cons.id
        ",
    )
end

"""
    _append_decommission_of_invested_units_ids_to_indices(connection, table_name, spec)

Appends, for each row of `cons_\$table_name`, the id of the investment variable of the vintage and the ids of
all the decommission variables of that vintage.
"""
function _append_decommission_of_invested_units_ids_to_indices(connection, table_name, spec)
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
            AND var_dec.commission_year < var_dec.milestone_year
        GROUP BY cons.id, $cons_columns, cons.commission_year
        ORDER BY cons.id
        ",
    )
end
