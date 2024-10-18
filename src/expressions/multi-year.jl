function create_multi_year_expressions!(model, graph, sets)
    @timeit to "multi-year investment expressions" begin
        # Unpacking
        assets_investment = model[:assets_investment]
        assets_decommission_simple_method = model[:assets_decommission_simple_method]
        assets_decommission_compact_method = model[:assets_decommission_compact_method]
        flows_investment = model[:flows_investment]
        flows_decommission_using_simple_method = model[:flows_decommission_using_simple_method]

        accumulated_initial_units = @expression(
            model,
            accumulated_initial_units[a in sets.A, y in sets.Y],
            sum(values(graph[a].initial_units[y]))
        )

        ### Expressions for multi-year investment simple method
        accumulated_investment_units_using_simple_method = @expression(
            model,
            accumulated_investment_units_using_simple_method[
                a ∈ sets.decommissionable_assets_using_simple_method,
                y in sets.Y,
            ],
            sum(
                assets_investment[yy, a] for
                yy in sets.Y if a ∈ sets.investable_assets_using_simple_method[yy] &&
                sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_using_simple_method[
                a ∈ sets.decommissionable_assets_using_simple_method,
                y in sets.Y,
            ],
            sum(
                assets_decommission_simple_method[yy, a] for
                yy in sets.Y if sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_units_simple_method[
                a ∈ sets.decommissionable_assets_using_simple_method,
                y ∈ sets.Y,
            ],
            accumulated_initial_units[a, y] +
            accumulated_investment_units_using_simple_method[a, y] -
            accumulated_decommission_units_using_simple_method[a, y]
        )

        ### Expressions for multi-year investment compact method
        @expression(
            model,
            accumulated_decommission_units_using_compact_method[(
                a,
                y,
                v,
            ) in sets.accumulated_set_using_compact_method],
            sum(
                assets_decommission_compact_method[(a, yy, v)] for yy in sets.Y if
                v ≤ yy ≤ y && (a, yy, v) in sets.decommission_set_using_compact_method
            )
        )
        cond1(a, y, v) = a in sets.existing_assets_by_year_using_compact_method[v]
        cond2(a, y, v) = v in sets.Y && a in sets.investable_assets_using_compact_method[v]
        accumulated_units_compact_method =
            model[:accumulated_units_compact_method] = JuMP.AffExpr[
                if cond1(a, y, v) && cond2(a, y, v)
                    @expression(
                        model,
                        graph[a].initial_units[y][v] + assets_investment[v, a] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                elseif cond1(a, y, v) && !cond2(a, y, v)
                    @expression(
                        model,
                        graph[a].initial_units[y][v] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                elseif !cond1(a, y, v) && cond2(a, y, v)
                    @expression(
                        model,
                        assets_investment[v, a] -
                        accumulated_decommission_units_using_compact_method[(a, y, v)]
                    )
                else
                    @expression(model, 0.0)
                end for (a, y, v) in sets.accumulated_set_using_compact_method
            ]

        ### Expressions for multi-year investment for accumulated units no matter the method
        model[:accumulated_units] = JuMP.AffExpr[
            if a in sets.decommissionable_assets_using_simple_method
                @expression(model, accumulated_units_simple_method[a, y])
            elseif a in sets.decommissionable_assets_using_compact_method
                @expression(
                    model,
                    sum(
                        accumulated_units_compact_method[sets.accumulated_set_using_compact_method_lookup[(
                            a,
                            y,
                            v,
                        )]] for v in sets.V_all if
                        (a, y, v) in sets.accumulated_set_using_compact_method
                    )
                )
            else
                @expression(model, sum(values(graph[a].initial_units[y])))
            end for a in sets.A for y in sets.Y
        ]
        ## Expressions for transport assets
        @expression(
            model,
            accumulated_investment_units_transport_using_simple_method[
                y ∈ sets.Y,
                (u, v) ∈ sets.Ft,
            ],
            sum(
                flows_investment[yy, (u, v)] for yy in sets.Y if (u, v) ∈ sets.Fi[yy] &&
                sets.starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_transport_using_simple_method[
                y ∈ sets.Y,
                (u, v) ∈ sets.Ft,
            ],
            sum(
                flows_decommission_using_simple_method[yy, (u, v)] for
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
end
