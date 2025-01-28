using Base: extract_names_and_defvals_from_kwdef_fieldblock!
function create_multi_year_expressions!(connection, model, graph, sets, variables, constraints)
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

    let table_name = :expr_accumulated_units
        var_inv = variables[:assets_investment].container
        var_dec = variables[:assets_decommission].container
        cons = constraints[table_name] = TulipaConstraint(connection, "$table_name")

        indices = DuckDB.query(connection, "FROM $table_name ORDER BY index")
        attach_expression!(
            cons,
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

    ## Old file below

    # Unpacking
    assets_investment = variables[:assets_investment].lookup
    # assets_decommission_simple_method = variables[:assets_decommission_simple_method].lookup
    # assets_decommission_compact_method = variables[:assets_decommission_compact_method].lookup
    flows_investment = variables[:flows_investment].lookup
    flows_decommission = variables[:flows_decommission].lookup
    #
    # accumulated_initial_units = @expression(
    #     model,
    #     accumulated_initial_units[a in sets.A, y in sets.Y],
    #     sum(values(graph[a].initial_units[y]))
    # )
    #
    # ### Expressions for multi-year investment simple method
    # accumulated_investment_units_using_simple_method = @expression(
    #     model,
    #     accumulated_investment_units_using_simple_method[
    #         a ∈ sets.decommissionable_assets_using_simple_method,
    #         y in sets.Y,
    #     ],
    #     sum(
    #         assets_investment[yy, a] for
    #         yy in sets.Y if a ∈ sets.investable_assets_using_simple_method[yy] &&
    #         sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     )
    # )
    # @expression(
    #     model,
    #     accumulated_decommission_units_using_simple_method[
    #         a ∈ sets.decommissionable_assets_using_simple_method,
    #         y in sets.Y,
    #     ],
    #     sum(
    #         assets_decommission_simple_method[yy, a] for
    #         yy in sets.Y if sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     )
    # )
    # @expression(
    #     model,
    #     accumulated_units_simple_method[
    #         a ∈ sets.decommissionable_assets_using_simple_method,
    #         y ∈ sets.Y,
    #     ],
    #     accumulated_initial_units[a, y] + accumulated_investment_units_using_simple_method[a, y] -
    #     accumulated_decommission_units_using_simple_method[a, y]
    # )
    #
    # ### Expressions for multi-year investment compact method
    # @expression(
    #     model,
    #     accumulated_decommission_units_using_compact_method[(
    #         a,
    #         y,
    #         v,
    #     ) in sets.accumulated_set_using_compact_method],
    #     sum(
    #         assets_decommission_compact_method[(a, yy, v)] for
    #         yy in sets.Y if v ≤ yy ≤ y && (a, yy, v) in sets.decommission_set_using_compact_method
    #     )
    # )
    # cond1(a, y, v) = a in sets.existing_assets_by_year_using_compact_method[v]
    # cond2(a, y, v) = v in sets.Y && a in sets.investable_assets_using_compact_method[v]
    # accumulated_units_compact_method =
    #     model[:accumulated_units_compact_method] = JuMP.AffExpr[
    #         if cond1(a, y, v) && cond2(a, y, v)
    #             @expression(
    #                 model,
    #                 graph[a].initial_units[y][v] + assets_investment[v, a] -
    #                 accumulated_decommission_units_using_compact_method[(a, y, v)]
    #             )
    #         elseif cond1(a, y, v) && !cond2(a, y, v)
    #             @expression(
    #                 model,
    #                 graph[a].initial_units[y][v] -
    #                 accumulated_decommission_units_using_compact_method[(a, y, v)]
    #             )
    #         elseif !cond1(a, y, v) && cond2(a, y, v)
    #             @expression(
    #                 model,
    #                 assets_investment[v, a] -
    #                 accumulated_decommission_units_using_compact_method[(a, y, v)]
    #             )
    #         else
    #             @expression(model, 0.0)
    #         end for (a, y, v) in sets.accumulated_set_using_compact_method
    #     ]
    #
    # ### Expressions for multi-year investment for accumulated units no matter the method
    # model[:accumulated_units] = JuMP.AffExpr[
    #     if a in sets.decommissionable_assets_using_simple_method
    #         @expression(model, accumulated_units_simple_method[a, y])
    #     elseif a in sets.decommissionable_assets_using_compact_method
    #         @expression(
    #             model,
    #             sum(
    #                 accumulated_units_compact_method[sets.accumulated_set_using_compact_method_lookup[(
    #                     a,
    #                     y,
    #                     v,
    #                 )]] for
    #                 v in sets.V_all if (a, y, v) in sets.accumulated_set_using_compact_method
    #             )
    #         )
    #     else
    #         @expression(model, sum(values(graph[a].initial_units[y])))
    #     end for a in sets.A for y in sets.Y
    # ]
    ## Expressions for transport assets
    @expression(
        model,
        accumulated_investment_units_transport_using_simple_method[y ∈ sets.Y, (u, v) ∈ sets.Ft],
        sum(
            flows_investment[yy, (u, v)] for yy in sets.Y if (u, v) ∈ sets.Fi[yy] &&
            sets.starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
        )
    )
    @expression(
        model,
        accumulated_decommission_units_transport_using_simple_method[y ∈ sets.Y, (u, v) ∈ sets.Ft],
        sum(
            flows_decommission[yy, (u, v)] for
            yy in sets.Y if sets.starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
        )
    )
    @expression(
        model,
        accumulated_flows_export_units[y ∈ sets.Y, (u, v) ∈ sets.Ft],
        sum(values(graph[u, v].initial_export_units[y])) +
        accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
        accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
    )
    @expression(
        model,
        accumulated_flows_import_units[y ∈ sets.Y, (u, v) ∈ sets.Ft],
        sum(values(graph[u, v].initial_import_units[y])) +
        accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
        accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
    )
end
