# Tools to prepare data and structures to the model creation
export create_sets

"""
    add_expression_terms_intra_rp_constraints!(df_cons,
                                               df_flows,
                                               workspace,
                                               representative_periods,
                                               graph;
                                               use_highest_resolution = true,
                                               multiply_by_duration = true,
                                               )

Computes the incoming and outgoing expressions per row of df_cons for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_terms_intra_rp_constraints!(
    cons::TulipaConstraint,
    flow::TulipaVariable,
    workspace,
    representative_periods,
    graph;
    use_highest_resolution = true,
    multiply_by_duration = true,
    add_min_outgoing_flow_duration = false,
)
    # Aggregating function: If the duration should NOT be taken into account, we have to compute unique appearances of the flows.
    # Otherwise, just use the sum
    agg = multiply_by_duration ? v -> sum(v) : v -> sum(unique(v))

    grouped_cons = DataFrames.groupby(cons.indices, [:year, :rep_period, :asset])

    # grouped_cons' asset will be matched with either to or from, depending on whether
    # we are filling incoming or outgoing flows
    cases = [
        (expr_key = :incoming, asset_match = :to, selected_assets = ["hub", "consumer"]),
        (
            expr_key = :outgoing,
            asset_match = :from,
            selected_assets = ["hub", "consumer", "producer"],
        ),
    ]
    num_rows = size(cons.indices, 1)

    for case in cases
        attach_expression!(cons, case.expr_key, Vector{JuMP.AffExpr}(undef, num_rows))
        cons.expressions[case.expr_key] .= JuMP.AffExpr(0.0)
        conditions_to_add_min_outgoing_flow_duration =
            add_min_outgoing_flow_duration && case.expr_key == :outgoing
        if conditions_to_add_min_outgoing_flow_duration
            # TODO: What to do about this?
            cons.indices[!, :min_outgoing_flow_duration] .= 1
        end
        grouped_flows = DataFrames.groupby(flow.indices, [:year, :rep_period, case.asset_match])
        for ((year, rep_period, asset), sub_df) in pairs(grouped_cons)
            if !haskey(grouped_flows, (year, rep_period, asset))
                continue
            end
            resolution =
                multiply_by_duration ? representative_periods[year][rep_period].resolution : 1.0
            for i in eachindex(workspace)
                workspace[i] = JuMP.AffExpr(0.0)
            end
            outgoing_flow_durations = typemax(Int64) #LARGE_NUMBER to start finding the minimum outgoing flow duration
            # Store the corresponding flow in the workspace
            for row in eachrow(grouped_flows[(year, rep_period, asset)])
                asset = row[case.asset_match]
                for t in row.time_block_start:row.time_block_end
                    # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                    # And when you want the highest resolution (which is asset type-agnostic)
                    efficiency_coefficient =
                        if graph[asset].type in case.selected_assets || use_highest_resolution
                            1.0
                        else
                            if case.expr_key == :incoming
                                row.efficiency
                            else
                                # Divide by efficiency for outgoing flows
                                1.0 / row.efficiency
                            end
                        end
                    JuMP.add_to_expression!(
                        workspace[t],
                        flow.container[row.index],
                        resolution * efficiency_coefficient,
                    )
                    if conditions_to_add_min_outgoing_flow_duration
                        outgoing_flow_durations = min(
                            outgoing_flow_durations,
                            row.time_block_end - row.time_block_start + 1,
                        )
                    end
                end
            end
            # Sum the corresponding flows from the workspace
            for row in eachrow(sub_df)
                # TODO: This is a hack to handle constraint tables that still have timesteps_block
                # In particular, storage_level_intra_rp
                cons.expressions[case.expr_key][row.index] =
                    agg(@view workspace[row.time_block_start:row.time_block_end])
                if conditions_to_add_min_outgoing_flow_duration
                    row[:min_outgoing_flow_duration] = outgoing_flow_durations
                end
            end
        end
    end
end

"""
    add_expression_is_charging_terms_intra_rp_constraints!(df_cons,
                                                       is_charging_indices,
                                                       is_charging_variables,
                                                       workspace
                                                       )

Computes the `is_charging` expressions per row of `df_cons` for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_is_charging_terms_intra_rp_constraints!(
    cons::TulipaConstraint,
    is_charging::TulipaVariable,
    workspace,
)
    # Aggregating function: We have to compute the proportion of each variable is_charging in the constraint timesteps_block.
    agg = Statistics.mean

    grouped_cons = DataFrames.groupby(cons.indices, [:year, :rep_period, :asset])

    cons.expressions[:is_charging] = Vector{JuMP.AffExpr}(undef, size(cons.indices, 1))
    cons.expressions[:is_charging] .= JuMP.AffExpr(0.0)
    grouped_is_charging = DataFrames.groupby(is_charging.indices, [:year, :rep_period, :asset])
    for ((year, rep_period, asset), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_is_charging, (year, rep_period, asset))
            continue
        end

        for i in eachindex(workspace)
            workspace[i] = JuMP.AffExpr(0.0)
        end
        # Store the corresponding variables in the workspace
        for row in eachrow(grouped_is_charging[(year, rep_period, asset)])
            asset = row[:asset]
            for t in row.time_block_start:row.time_block_end
                JuMP.add_to_expression!(workspace[t], is_charging.container[row.index])
            end
        end
        # Apply the agg funtion to the corresponding variables from the workspace
        for row in eachrow(sub_df)
            cons.expressions[:is_charging][row.index] =
                agg(@view workspace[row.time_block_start:row.time_block_end])
        end
    end
end

"""
    add_expression_units_on_terms_intra_rp_constraints!(
        df_cons,
        df_units_on,
        workspace,
    )

Computes the `units_on` expressions per row of `df_cons` for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_units_on_terms_intra_rp_constraints!(
    cons::TulipaConstraint,
    units_on::TulipaVariable,
    workspace,
)
    # Aggregating function: since the constraint is in the highest resolution we can aggregate with unique.
    agg = v -> sum(unique(v))

    grouped_cons = DataFrames.groupby(cons.indices, [:rep_period, :asset])

    cons.expressions[:units_on] = Vector{JuMP.AffExpr}(undef, size(cons.indices, 1))
    cons.expressions[:units_on] .= JuMP.AffExpr(0.0)
    grouped_units_on = DataFrames.groupby(units_on.indices, [:rep_period, :asset])
    for ((rep_period, asset), sub_df) in pairs(grouped_cons)
        haskey(grouped_units_on, (rep_period, asset)) || continue

        for i in eachindex(workspace)
            workspace[i] = JuMP.AffExpr(0.0)
        end
        # Store the corresponding variables in the workspace
        for row in eachrow(grouped_units_on[(rep_period, asset)])
            for t in row.time_block_start:row.time_block_end
                JuMP.add_to_expression!(workspace[t], units_on.container[row.index])
            end
        end
        # Apply the agg funtion to the corresponding variables from the workspace
        for row in eachrow(sub_df)
            cons.expressions[:units_on][row.index] =
                agg(@view workspace[row.time_block_start:row.time_block_end])
        end
    end
end

"""
    add_expression_terms_inter_rp_constraints!(df_inter,
                                               df_flows,
                                               df_map,
                                               graph,
                                               representative_periods,
                                               )

Computes the incoming and outgoing expressions per row of df_inter for the constraints
that are between (inter) the representative periods.

This function is only used internally in the model.

"""
function add_expression_terms_inter_rp_constraints!(
    cons::TulipaConstraint,
    flow::TulipaVariable,
    df_map, # TODO: Figure out how to handle this
    graph,
    representative_periods;
    is_storage_level = false,
)
    num_rows = size(cons.indices, 1)
    cons.expressions[:outgoing] = Vector{JuMP.AffExpr}(undef, num_rows)
    cons.expressions[:outgoing] .= JuMP.AffExpr(0.0)

    if is_storage_level
        cons.expressions[:incoming] = Vector{JuMP.AffExpr}(undef, num_rows)
        cons.expressions[:incoming] .= JuMP.AffExpr(0.0)
        cons.expressions[:inflows_profile_aggregation] = Vector{JuMP.AffExpr}(undef, num_rows)
        cons.expressions[:inflows_profile_aggregation] .= JuMP.AffExpr(0.0)
    end

    # TODO: The interaction between year and timeframe is not clear yet, so this is probably wrong
    #   At this moment, that relation is ignored (we don't even look at df_inter.year)

    # Incoming, outgoing flows, and profile aggregation
    for row_cons in eachrow(cons.indices)
        sub_df_map = filter(
            :period => p -> row_cons.period_block_start <= p <= row_cons.period_block_end,
            df_map;
            view = true,
        )

        for row_map in eachrow(sub_df_map)
            # Skip inactive row_cons or undefined for that year
            # TODO: This is apparently never happening
            # if !get(graph[row_cons.asset].active, row_map.year, false)
            #     continue
            # end

            sub_df_flows = filter(
                [:from, :year, :rep_period] =>
                    (from, y, rp) ->
                        (from, y, rp) == (row_cons.asset, row_map.year, row_map.rep_period),
                flow.indices;
                view = true,
            )
            sub_df_flows.duration = sub_df_flows.time_block_end - sub_df_flows.time_block_start .+ 1
            if is_storage_level
                cons.expressions[:outgoing][row_cons.index] +=
                    LinearAlgebra.dot(
                        flow.container[sub_df_flows.index],
                        sub_df_flows.duration ./ sub_df_flows.efficiency,
                    ) * row_map.weight
            else
                cons.expressions[:outgoing][row_cons.index] +=
                    LinearAlgebra.dot(flow.container[sub_df_flows.index], sub_df_flows.duration) *
                    row_map.weight
            end

            if is_storage_level
                # TODO: There is some repetition here or am I missing something?
                sub_df_flows = filter(
                    [:to, :year, :rep_period] =>
                        (to, y, rp) ->
                            (to, y, rp) == (row_cons.asset, row_map.year, row_map.rep_period),
                    flow.indices;
                    view = true,
                )
                sub_df_flows.duration =
                    sub_df_flows.time_block_end - sub_df_flows.time_block_start .+ 1

                cons.expressions[:incoming][row_cons.index] +=
                    LinearAlgebra.dot(
                        flow.container[sub_df_flows.index],
                        sub_df_flows.duration .* sub_df_flows.efficiency,
                    ) * row_map.weight

                cons.expressions[:inflows_profile_aggregation][row_cons.index] +=
                    profile_aggregation(
                        sum,
                        graph[row_cons.asset].rep_periods_profiles,
                        row_map.year,
                        row_map.year,
                        ("inflows", row_map.rep_period),
                        representative_periods[row_map.year][row_map.rep_period].timesteps,
                        0.0,
                    ) *
                    graph[row_cons.asset].storage_inflows[row_map.year] *
                    row_map.weight
            end
        end
    end
end

function add_expressions_to_constraints!(
    variables,
    constraints,
    model,
    expression_workspace,
    representative_periods,
    timeframe,
    graph,
)
    # Unpack variables
    # Creating the incoming and outgoing flow expressions
    @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
        constraints[:balance_conversion],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
        constraints[:balance_storage_rep_period],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_intra_rp_constraints!"
    add_expression_terms_intra_rp_constraints!(
        constraints[:balance_consumer],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
        constraints[:balance_hub],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
        constraints[:highest_in],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
        constraints[:highest_out],
        variables[:flow],
        expression_workspace,
        representative_periods,
        graph;
        use_highest_resolution = true,
        multiply_by_duration = false,
        add_min_outgoing_flow_duration = true,
    )
    if !isempty(constraints[:units_on_and_outflows].indices)
        @timeit to "add_expression_terms_intra_rp_constraints!" add_expression_terms_intra_rp_constraints!(
            constraints[:units_on_and_outflows],
            variables[:flow],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
            add_min_outgoing_flow_duration = true,
        )
    end
    @timeit to "add_expression_terms_inter_rp_constraints!" add_expression_terms_inter_rp_constraints!(
        constraints[:balance_storage_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods;
        is_storage_level = true,
    )
    @timeit to "add_expression_terms_inter_rp_constraints!" add_expression_terms_inter_rp_constraints!(
        constraints[:max_energy_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods,
    )
    @timeit to "add_expression_terms_inter_rp_constraints!" add_expression_terms_inter_rp_constraints!(
        constraints[:min_energy_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods,
    )
    @timeit to "add_expression_is_charging_terms_intra_rp_constraints!" add_expression_is_charging_terms_intra_rp_constraints!(
        constraints[:highest_in],
        variables[:is_charging],
        expression_workspace,
    )
    @timeit to "add_expression_is_charging_terms_intra_rp_constraints!" add_expression_is_charging_terms_intra_rp_constraints!(
        constraints[:highest_out],
        variables[:is_charging],
        expression_workspace,
    )
    if !isempty(constraints[:units_on_and_outflows].indices)
        @timeit to "add_expression_units_on_terms_intra_rp_constraints!" add_expression_units_on_terms_intra_rp_constraints!(
            constraints[:units_on_and_outflows],
            variables[:units_on],
            expression_workspace,
        )
    end

    return
end

function create_sets(graph, years)
    # TODO: Some of the things here are not actually sets, but they're used to
    # create other sets or conditions In the near future we might change these
    # to create the set here beforehand and don't export the additional things,
    # only sets (which is what makes the code more efficient, anyway)
    A = MetaGraphsNext.labels(graph) |> collect
    F = MetaGraphsNext.edge_labels(graph) |> collect
    Ac = filter_graph(graph, A, "consumer", :type)
    Ap = filter_graph(graph, A, "producer", :type)
    As = filter_graph(graph, A, "storage", :type)
    Ah = filter_graph(graph, A, "hub", :type)
    Acv = filter_graph(graph, A, "conversion", :type)
    Ft = filter_graph(graph, F, true, :is_transport)

    Y = [year.id for year in years if year.is_milestone]
    V_all = [year.id for year in years]
    V_non_milestone = [year.id for year in years if !year.is_milestone]

    # Create subsets of assets by investable
    Ai = Dict(y => filter_graph(graph, A, true, :investable, y) for y in Y)
    Fi = Dict(y => filter_graph(graph, F, true, :investable, y) for y in Y)

    # Create a subset of years by investable assets, i.e., inverting Ai
    Yi =
        Dict(a => [y for y in Y if a in Ai[y]] for a in A if any(graph[a].investable[y] for y in Y))

    # Create subsets of investable/decommissionable assets by investment method
    investable_assets_using_simple_method =
        Dict(y => Ai[y] ∩ filter_graph(graph, A, "simple", :investment_method) for y in Y)
    decommissionable_assets_using_simple_method =
        filter_graph(graph, A, "simple", :investment_method)

    investable_assets_using_compact_method =
        Dict(y => Ai[y] ∩ filter_graph(graph, A, "compact", :investment_method) for y in Y)
    decommissionable_assets_using_compact_method =
        filter_graph(graph, A, "compact", :investment_method)

    # Create dicts for the start year of investments that are accumulated in year y
    starting_year_using_simple_method = Dict(
        (y, a) => y - graph[a].technical_lifetime + 1 for y in Y for
        a in decommissionable_assets_using_simple_method
    )

    starting_year_using_compact_method = Dict(
        (y, a) => y - graph[a].technical_lifetime + 1 for y in Y for
        a in decommissionable_assets_using_compact_method
    )

    starting_year_flows_using_simple_method =
        Dict((y, (u, v)) => y - graph[u, v].technical_lifetime + 1 for y in Y for (u, v) in Ft)

    # Create a subset of decommissionable_assets_using_compact_method: existing assets invested in non-milestone years
    existing_assets_by_year_using_compact_method = Dict(
        y =>
            [
                a for a in decommissionable_assets_using_compact_method for
                inner_dict in values(graph[a].initial_units) for
                k in keys(inner_dict) if k == y && inner_dict[k] != 0
            ] |> unique for y in V_all
    )

    # Create sets of tuples for decommission variables/accumulated capacity of compact method

    # Create conditions for decommission variables
    # Cond1: asset a invested in year v has to be operational at milestone year y
    # Cond2: invested in non-milestone years (i.e., initial units from non-milestone years), or
    # Cond3: invested in investable milestone years, or initial units from milestone years
    cond1_domain_decommission_variables(a, y, v) = starting_year_using_compact_method[y, a] ≤ v < y
    cond2_domain_decommission_variables(a, v) =
        (v in V_non_milestone && a in existing_assets_by_year_using_compact_method[v])
    cond3_domain_decommission_variables(a, v) =
        v in Y &&
        (a in investable_assets_using_compact_method[v] || (graph[a].initial_units[v][v] != 0))

    decommission_set_using_compact_method = [
        (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
        v in V_all if cond1_domain_decommission_variables(a, y, v) &&
        (cond2_domain_decommission_variables(a, v) || cond3_domain_decommission_variables(a, v))
    ]

    # Create conditions for accumulated units compact method
    # Cond1: asset a invested in year v has to be operational at milestone year y
    # Note it is different from cond1_domain_decommission_variables because here, we allow accumulation at the year of investment
    # Cond2: same as cond2_domain_decommission_variables(a, v)
    # Cond3: same as cond3_domain_decommission_variables(a, v)
    cond1_domain_accumulated_units_using_compact_method(a, y, v) =
        starting_year_using_compact_method[y, a] ≤ v ≤ y

    accumulated_set_using_compact_method = [
        (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
        v in V_all if cond1_domain_accumulated_units_using_compact_method(a, y, v) &&
        (cond2_domain_decommission_variables(a, v) || cond3_domain_decommission_variables(a, v))
    ]

    # Create a lookup set for compact method
    accumulated_set_using_compact_method_lookup = Dict(
        (a, y, v) => idx for (idx, (a, y, v)) in enumerate(accumulated_set_using_compact_method)
    )

    # Create subsets of storage assets
    Ase = Dict(y => As ∩ filter_graph(graph, A, true, :storage_method_energy, y) for y in Y)
    Asb = As ∩ filter_graph(graph, A, ["binary", "relaxed_binary"], :use_binary_storage_method)

    # Create subsets of assets for ramping and unit commitment for producers and conversion assets
    Ar = (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :ramping)
    Auc = (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :unit_commitment)
    Auc_integer = Auc ∩ filter_graph(graph, A, true, :unit_commitment_integer)
    Auc_basic = Auc ∩ filter_graph(graph, A, "basic", :unit_commitment_method)

    ### Sets for expressions in multi-year investment for accumulated units no matter the method
    accumulated_units_lookup =
        Dict((a, y) => idx for (idx, (a, y)) in enumerate((aa, yy) for aa in A for yy in Y))

    # TODO: Create a better structure if this is still necessary later
    return (; # This is a NamedTuple
        A,
        Ac,
        Acv,
        Ah,
        Ai,
        Ap,
        Ar,
        As,
        Asb,
        Ase,
        Auc,
        Auc_basic,
        Auc_integer,
        F,
        Fi,
        Ft,
        V_all,
        V_non_milestone,
        Y,
        accumulated_set_using_compact_method,
        accumulated_set_using_compact_method_lookup,
        accumulated_units_lookup,
        decommission_set_using_compact_method,
        decommissionable_assets_using_compact_method,
        decommissionable_assets_using_simple_method,
        existing_assets_by_year_using_compact_method,
        investable_assets_using_compact_method,
        investable_assets_using_simple_method,
        starting_year_flows_using_simple_method,
        starting_year_using_simple_method,
    )
end
