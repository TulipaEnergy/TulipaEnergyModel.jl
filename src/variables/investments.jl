export add_investment_variables!

"""
    add_investment_variables!(model, graph, sets)

Adds investment, decommission, and energy-related variables to the optimization `model`,
and sets integer constraints on selected variables based on the `graph` data.

"""
function add_investment_variables!(model, graph, sets, variables)
    model[:flows_investment] = [
        @variable(
            model,
            lower_bound = 0.0,
            integer = row.investment_integer,
            base_name = "flows_investment[$(row.from_asset),$(row.to_asset),$(row.year)]"
        ) for row in eachrow(variables[:flows_investment].indices)
    ]

    @variable(model, 0 ≤ assets_investment[y in sets.Y, a in sets.Ai[y]])

    @variable(
        model,
        0 ≤ assets_decommission_simple_method[
            y in sets.Y,
            a in sets.decommissionable_assets_using_simple_method,
        ]
    )

    @variable(
        model,
        0 <=
        assets_decommission_compact_method[(a, y, v) in sets.decommission_set_using_compact_method]
    )

    @variable(model, 0 ≤ flows_decommission_using_simple_method[y in sets.Y, (u, v) in sets.Ft])

    @variable(model, 0 ≤ assets_investment_energy[y in sets.Y, a in sets.Ase[y]∩sets.Ai[y]])

    @variable(
        model,
        0 ≤ assets_decommission_energy_simple_method[
            y in sets.Y,
            a in sets.Ase[y]∩sets.decommissionable_assets_using_simple_method,
        ]
    )

    ### Integer Investment Variables
    for y in sets.Y, a in sets.Ai[y]
        if graph[a].investment_integer[y]
            JuMP.set_integer(assets_investment[y, a])
        end
    end

    for y in sets.Y, a in sets.decommissionable_assets_using_simple_method
        if graph[a].investment_integer[y]
            JuMP.set_integer(assets_decommission_simple_method[y, a])
        end
    end

    for (a, y, v) in sets.decommission_set_using_compact_method
        # We don't do anything with existing units (because it can be integers or non-integers)
        if !(
            v in sets.V_non_milestone && a in sets.existing_assets_by_year_using_compact_method[y]
        ) && graph[a].investment_integer[y]
            JuMP.set_integer(assets_decommission_compact_method[(a, y, v)])
        end
    end

    for y in sets.Y, a in sets.Ase[y] ∩ sets.Ai[y]
        if graph[a].investment_integer_storage_energy[y]
            JuMP.set_integer(assets_investment_energy[y, a])
        end
    end

    for y in sets.Y, a in sets.Ase[y] ∩ sets.decommissionable_assets_using_simple_method
        if graph[a].investment_integer_storage_energy[y]
            JuMP.set_integer(assets_decommission_energy_simple_method[y, a])
        end
    end

    return
end
