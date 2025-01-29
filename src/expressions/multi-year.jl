function create_multi_year_expressions!(connection, model, graph, sets, variables, expressions)
    # The variable assets_decommission is defined for (a, my, cy)
    # The capacity expression that we need to compute is
    #
    #   profile_times_capacity[a, my] = ∑_cy agg(
    #     profile[
    #       profile_name[a, cy, 'availability'], my, rp)
    #     ],
    #     time_block
    #   ) * accumulated_units[a, my, cy]
    #
    # where
    #
    # - a=asset, my=milestone_year, cy=commission_year, rp=rep_period
    # - profile_name[a, cy, 'availability']: name of profile for (a, cy, 'availability')
    # - profile[p_name, my, rp]: profile vector named `p_name` for my and rp (or some default value, ignored here)
    # - agg(p_vector, time_block): some aggregation of vector p_vector over time_block
    #
    # and
    #
    #   accumulated_units[a, my, cy] = investment_units[a, cy] - assets_decommission[a, my, cy] + initial_units[a, my, cy]
    #
    # Assumption:
    # - asset_both exists only for (a,my,cy) where technical lifetime was already taken into account

    _create_multi_year_expressions_indices!(connection, expressions)

    let table_name = :accumulated_units, expr = expressions[table_name]
        var_inv = variables[:assets_investment].container
        var_dec = variables[:assets_decommission].container

        indices = DuckDB.query(connection, "FROM expr_$table_name ORDER BY index")
        attach_expression!(
            expr,
            :accumulated_units,
            JuMP.AffExpr[
                if ismissing(row.var_decommission_index) && ismissing(row.var_investment_index)
                    @expression(model, row.initial_units)
                elseif ismissing(row.var_investment_index)
                    @expression(model, row.initial_units - var_dec[row.var_decommission_index])
                elseif ismissing(row.var_decommission_index)
                    @expression(model, row.initial_units + var_inv[row.var_investment_index])
                else
                    @expression(
                        model,
                        row.initial_units + var_inv[row.var_investment_index] -
                        var_dec[row.var_decommission_index]
                    )
                end for row in indices
            ],
        )
    end

    let table_name = :accumulated_flow_units, expr = expressions[table_name]
        var_inv = variables[:flows_investment].container
        var_dec = variables[:flows_decommission].container

        indices = DuckDB.query(connection, "FROM expr_$table_name ORDER BY index")
        attach_expression!(
            expr,
            :export,
            JuMP.AffExpr[
                if ismissing(row.var_decommission_index) && ismissing(row.var_investment_index)
                    @expression(model, row.initial_export_units)
                elseif ismissing(row.var_investment_index)
                    @expression(
                        model,
                        row.initial_export_units - var_dec[row.var_decommission_index]
                    )
                elseif ismissing(row.var_decommission_index)
                    @expression(
                        model,
                        row.initial_export_units + var_inv[row.var_investment_index]
                    )
                else
                    @expression(
                        model,
                        row.initial_export_units + var_inv[row.var_investment_index] -
                        var_dec[row.var_decommission_index]
                    )
                end for row in indices
            ],
        )

        attach_expression!(
            expr,
            :import,
            JuMP.AffExpr[
                if ismissing(row.var_decommission_index) && ismissing(row.var_investment_index)
                    @expression(model, row.initial_import_units)
                elseif ismissing(row.var_investment_index)
                    @expression(
                        model,
                        row.initial_import_units - var_dec[row.var_decommission_index]
                    )
                elseif ismissing(row.var_decommission_index)
                    @expression(
                        model,
                        row.initial_import_units + var_inv[row.var_investment_index]
                    )
                else
                    @expression(
                        model,
                        row.initial_import_units + var_inv[row.var_investment_index] -
                        var_dec[row.var_decommission_index]
                    )
                end for row in indices
            ],
        )
    end

    let table_name = :accumulated_units_energy, expr = expressions[table_name]
        var_inv = variables[:assets_investment_energy].container
        var_dec = variables[:assets_decommission_energy].container

        indices = DuckDB.query(connection, "FROM expr_$table_name ORDER BY index")
        attach_expression!(
            expr,
            :accumulated_units_energy,
            JuMP.AffExpr[
                if ismissing(row.var_decommission_index) && ismissing(row.var_investment_index)
                    @expression(model, row.initial_units)
                elseif ismissing(row.var_investment_index)
                    @expression(model, row.initial_units - var_dec[row.var_decommission_index])
                elseif ismissing(row.var_decommission_index)
                    @expression(model, row.initial_units + var_inv[row.var_investment_index])
                else
                    @expression(
                        model,
                        row.initial_units + var_inv[row.var_investment_index] -
                        var_dec[row.var_decommission_index]
                    )
                end for row in indices
            ],
        )
    end
end

function _create_multi_year_expressions_indices!(connection, expressions)
    DuckDB.query(
        connection,
        "
        CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_accumulated_units AS
        SELECT
            nextval('id') AS index,
            asset_both.asset,
            asset_both.milestone_year,
            asset_both.commission_year,
            asset_both.initial_units,
            var_dec.index AS var_decommission_index,
            var_inv.index AS var_investment_index,
        FROM asset_both
        LEFT JOIN var_assets_decommission AS var_dec
            ON asset_both.asset = var_dec.asset
            AND asset_both.commission_year = var_dec.commission_year
            AND asset_both.milestone_year = var_dec.milestone_year
        LEFT JOIN var_assets_investment AS var_inv
            ON asset_both.asset = var_inv.asset
            AND asset_both.commission_year = var_inv.milestone_year
        ",
    )

    DuckDB.query(
        connection,
        "
        CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_accumulated_flow_units AS
        SELECT
            nextval('id') AS index,
            flow_both.to_asset,
            flow_both.from_asset,
            flow_both.milestone_year,
            flow_both.commission_year,
            flow_both.initial_export_units,
            flow_both.initial_import_units,
            var_dec.index AS var_decommission_index,
            var_inv.index AS var_investment_index,
        FROM flow_both
        LEFT JOIN var_flows_decommission AS var_dec
            ON flow_both.to_asset = var_dec.to_asset
            AND flow_both.from_asset = var_dec.from_asset
            AND flow_both.commission_year = var_dec.commission_year
            AND flow_both.milestone_year = var_dec.milestone_year
        LEFT JOIN var_flows_investment AS var_inv
            ON flow_both.to_asset = var_inv.to_asset
            AND flow_both.from_asset = var_inv.from_asset
            AND flow_both.commission_year = var_inv.milestone_year
        ",
    )

    DuckDB.query(
        connection,
        "
        CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_accumulated_units_energy AS
        SELECT
            nextval('id') AS index,
            asset_both.asset,
            asset_both.milestone_year,
            asset_both.commission_year,
            asset_both.initial_units,
            var_dec.index AS var_decommission_index,
            var_inv.index AS var_investment_index,
        FROM asset_both
        LEFT JOIN var_assets_decommission_energy AS var_dec
            ON asset_both.asset = var_dec.asset
            AND asset_both.commission_year = var_dec.commission_year
            AND asset_both.milestone_year = var_dec.milestone_year
        LEFT JOIN var_assets_investment_energy AS var_inv
            ON asset_both.asset = var_inv.asset
            AND asset_both.commission_year = var_inv.milestone_year
        ",
    )

    for expr_name in (:accumulated_units, :accumulated_flow_units, :accumulated_units_energy)
        expressions[expr_name] = TulipaExpression(connection, "expr_$expr_name")
    end

    return nothing
end
