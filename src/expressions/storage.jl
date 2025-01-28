function add_storage_expressions!(model, graph, sets, variables)
    # assets_investment_energy = variables[:assets_investment_energy].lookup
    # assets_decommission_energy_simple_method =
    #     variables[:assets_decommission_energy_simple_method].lookup
    # accumulated_investment_units_using_simple_method =
    #     model[:accumulated_investment_units_using_simple_method]
    # accumulated_decommission_units_using_simple_method =
    #     model[:accumulated_decommission_units_using_simple_method]
    #
    # @expression(
    #     model,
    #     accumulated_energy_units_simple_method[
    #         y ∈ sets.Y,
    #         a ∈ sets.Ase[y]∩sets.decommissionable_assets_using_simple_method,
    #     ],
    #     sum(values(graph[a].initial_storage_units[y])) + sum(
    #         assets_investment_energy[yy, a] for
    #         yy in sets.Y if a ∈ (sets.Ase[yy] ∩ sets.investable_assets_using_simple_method[yy]) &&
    #         sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     ) - sum(
    #         assets_decommission_energy_simple_method[yy, a] for yy in sets.Y if
    #         a ∈ sets.Ase[yy] && sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     )
    # )
    # @expression(
    #     model,
    #     accumulated_energy_capacity[y ∈ sets.Y, a ∈ sets.As],
    #     if graph[a].storage_method_energy &&
    #        a ∈ sets.Ase ∩ sets.decommissionable_assets_using_simple_method
    #         graph[a].capacity_storage_energy * accumulated_energy_units_simple_method[y, a]
    #     else
    #         (
    #             graph[a].capacity_storage_energy * sum(values(graph[a].initial_storage_units[y])) +
    #             if a ∈ sets.Ai[y] ∩ sets.decommissionable_assets_using_simple_method
    #                 graph[a].energy_to_power_ratio *
    #                 graph[a].capacity *
    #                 (
    #                     accumulated_investment_units_using_simple_method[a, y] -
    #                     accumulated_decommission_units_using_simple_method[a, y]
    #                 )
    #             else
    #                 0.0
    #             end
    #         )
    #     end
    # )
end
