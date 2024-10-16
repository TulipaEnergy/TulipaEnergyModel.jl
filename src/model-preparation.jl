# Tools to prepare data and structures to the model creation

"""
    dataframes = construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,, IteratorSize
        years,
    )

Computes the data frames used to linearize the variables and constraints. These are used
internally in the model only.
"""
function construct_dataframes(graph, representative_periods, constraints_partitions, years_struct)
    years = [year.id for year in years_struct if year.is_milestone]
    A = MetaGraphsNext.labels(graph) |> collect
    F = MetaGraphsNext.edge_labels(graph) |> collect
    RP = Dict(year => 1:length(representative_periods[year]) for year in years)

    # Create subsets of assets
    Ap  = filter_graph(graph, A, "producer", :type)
    Acv = filter_graph(graph, A, "conversion", :type)
    Auc = Dict(year => (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :unit_commitment, year) for year in years)

    # Output object
    dataframes = Dict{Symbol,DataFrame}()

    # Create all the dataframes for the constraints considering the constraints_partitions
    for (key, partitions) in constraints_partitions
        if length(partitions) == 0
            # No data, but ensure schema is correct
            dataframes[key] = DataFrame(;
                asset = String[],
                year = Int[],
                rep_period = Int[],
                timesteps_block = UnitRange{Int}[],
                index = Int[],
            )
            continue
        end

        # This construction should ensure the ordering of the time blocks for groups of (a, rp)
        df = DataFrame(
            (
                (
                    (asset = a, year = y, rep_period = rp, timesteps_block = timesteps_block) for
                    timesteps_block in partition
                ) for ((a, y, rp), partition) in partitions
            ) |> Iterators.flatten,
        )
        df.index = 1:size(df, 1)
        dataframes[key] = df
    end

    # DataFrame to store the flow variables
    dataframes[:flows] = DataFrame(
        (
            (
                (
                    from = u,
                    to = v,
                    year = y,
                    rep_period = rp,
                    timesteps_block = timesteps_block,
                    efficiency = graph[u, v].efficiency[y],
                ) for timesteps_block in graph[u, v].rep_periods_partitions[y][rp]
            ) for (u, v) in F, y in years for rp in RP[y] if get(graph[u, v].active, y, false)
        ) |> Iterators.flatten,
    )
    dataframes[:flows].index = 1:size(dataframes[:flows], 1)

    # DataFrame to store the units_on variables
    dataframes[:units_on] = DataFrame(
        (
            (
                (asset = a, year = y, rep_period = rp, timesteps_block = timesteps_block) for
                timesteps_block in graph[a].rep_periods_partitions[y][rp]
            ) for y in years for a in Auc[y], rp in RP[y] if get(graph[a].active, y, false)
        ) |> Iterators.flatten,
    )
    dataframes[:units_on].index = 1:size(dataframes[:units_on], 1)

    # Dataframe to store the storage level variable between (inter) representative period (e.g., seasonal storage)
    # Only for storage assets
    dataframes[:storage_level_inter_rp] =
        _construct_inter_rp_dataframes(A, graph, years, a -> a.type == "storage")

    # Dataframe to store the constraints for assets with maximum energy between (inter) representative periods
    # Only for assets with max energy limit
    dataframes[:max_energy_inter_rp] = _construct_inter_rp_dataframes(
        A,
        graph,
        years,
        a -> any(!ismissing, values(a.max_energy_timeframe_partition)),
    )

    # Dataframe to store the constraints for assets with minimum energy between (inter) representative periods
    # Only for assets with min energy limit
    dataframes[:min_energy_inter_rp] = _construct_inter_rp_dataframes(
        A,
        graph,
        years,
        a -> any(!ismissing, values(a.min_energy_timeframe_partition)),
    )

    return dataframes
end

"""
    df = _construct_inter_rp_dataframes(assets, graph, years, asset_filter)

Constructs dataframes for inter representative period constraints.

# Arguments
- `assets`: An array of assets.
- `graph`: The energy problem graph with the assets data.
- `asset_filter`: A function that filters assets based on certain criteria.

# Returns
A dataframe containing the constructed dataframe for constraints.

"""
function _construct_inter_rp_dataframes(assets, graph, years, asset_filter)
    local_filter(a, y) =
        get(graph[a].active, y, false) &&
        haskey(graph[a].timeframe_partitions, y) &&
        asset_filter(graph[a])

    df = DataFrame(
        (
            (
                (asset = a, year = y, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions[y]
            ) for a in assets, y in years if local_filter(a, y)
        ) |> Iterators.flatten,
    )
    if size(df, 1) == 0
        df = DataFrame(; asset = String[], year = Int[], periods_block = PeriodsBlock[])
    end
    df.index = 1:size(df, 1)
    return df
end

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
    df_cons,
    df_flows,
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

    grouped_cons = DataFrames.groupby(df_cons, [:year, :rep_period, :asset])

    # grouped_cons' asset will be matched with either to or from, depending on whether
    # we are filling incoming or outgoing flows
    cases = [
        (col_name = :incoming_flow, asset_match = :to, selected_assets = ["hub", "consumer"]),
        (
            col_name = :outgoing_flow,
            asset_match = :from,
            selected_assets = ["hub", "consumer", "producer"],
        ),
    ]

    for case in cases
        df_cons[!, case.col_name] .= JuMP.AffExpr(0.0)
        conditions_to_add_min_outgoing_flow_duration =
            add_min_outgoing_flow_duration && case.col_name == :outgoing_flow
        if conditions_to_add_min_outgoing_flow_duration
            df_cons[!, :min_outgoing_flow_duration] .= 1
        end
        grouped_flows = DataFrames.groupby(df_flows, [:year, :rep_period, case.asset_match])
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
                for t in row.timesteps_block
                    # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                    # And when you want the highest resolution (which is asset type-agnostic)
                    efficiency_coefficient =
                        if graph[asset].type in case.selected_assets || use_highest_resolution
                            1.0
                        else
                            if case.col_name == :incoming_flow
                                row.efficiency
                            else
                                # Divide by efficiency for outgoing flows
                                1.0 / row.efficiency
                            end
                        end
                    JuMP.add_to_expression!(
                        workspace[t],
                        row.flow,
                        resolution * efficiency_coefficient,
                    )
                    if conditions_to_add_min_outgoing_flow_duration
                        outgoing_flow_durations =
                            min(outgoing_flow_durations, length(row.timesteps_block))
                    end
                end
            end
            # Sum the corresponding flows from the workspace
            for row in eachrow(sub_df)
                row[case.col_name] = agg(@view workspace[row.timesteps_block])
                if conditions_to_add_min_outgoing_flow_duration
                    row[:min_outgoing_flow_duration] = outgoing_flow_durations
                end
            end
        end
    end
end

"""
    add_expression_is_charging_terms_intra_rp_constraints!(df_cons,
                                                       df_is_charging,
                                                       workspace
                                                       )

Computes the `is_charging` expressions per row of `df_cons` for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_is_charging_terms_intra_rp_constraints!(df_cons, df_is_charging, workspace)
    # Aggregating function: We have to compute the proportion of each variable is_charging in the constraint timesteps_block.
    agg = Statistics.mean

    grouped_cons = DataFrames.groupby(df_cons, [:year, :rep_period, :asset])

    df_cons[!, :is_charging] .= JuMP.AffExpr(0.0)
    grouped_is_charging = DataFrames.groupby(df_is_charging, [:year, :rep_period, :asset])
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
            for t in row.timesteps_block
                JuMP.add_to_expression!(workspace[t], row.is_charging)
            end
        end
        # Apply the agg funtion to the corresponding variables from the workspace
        for row in eachrow(sub_df)
            row[:is_charging] = agg(@view workspace[row.timesteps_block])
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
function add_expression_units_on_terms_intra_rp_constraints!(df_cons, df_units_on, workspace)
    # Aggregating function: since the constraint is in the highest resolution we can aggregate with unique.
    agg = v -> sum(unique(v))

    grouped_cons = DataFrames.groupby(df_cons, [:rep_period, :asset])

    df_cons[!, :units_on] .= JuMP.AffExpr(0.0)
    grouped_units_on = DataFrames.groupby(df_units_on, [:rep_period, :asset])
    for ((rep_period, asset), sub_df) in pairs(grouped_cons)
        haskey(grouped_units_on, (rep_period, asset)) || continue

        for i in eachindex(workspace)
            workspace[i] = JuMP.AffExpr(0.0)
        end
        # Store the corresponding variables in the workspace
        for row in eachrow(grouped_units_on[(rep_period, asset)])
            for t in row.timesteps_block
                JuMP.add_to_expression!(workspace[t], row.units_on)
            end
        end
        # Apply the agg funtion to the corresponding variables from the workspace
        for row in eachrow(sub_df)
            row[:units_on] = agg(@view workspace[row.timesteps_block])
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
    df_inter,
    df_flows,
    df_map,
    graph,
    representative_periods;
    is_storage_level = false,
)
    df_inter[!, :outgoing_flow] .= JuMP.AffExpr(0.0)

    if is_storage_level
        df_inter[!, :incoming_flow] .= JuMP.AffExpr(0.0)
        df_inter[!, :inflows_profile_aggregation] .= JuMP.AffExpr(0.0)
    end

    # TODO: The interaction between year and timeframe is not clear yet, so this is probably wrong
    #   At this moment, that relation is ignored (we don't even look at df_inter.year)

    # Incoming, outgoing flows, and profile aggregation
    for row_inter in eachrow(df_inter)
        sub_df_map = filter(:period => in(row_inter.periods_block), df_map; view = true)

        for row_map in eachrow(sub_df_map)
            # Skip inactive row_inter or undefined for that year
            # TODO: This is apparently never happening
            # if !get(graph[row_inter.asset].active, row_map.year, false)
            #     continue
            # end

            sub_df_flows = filter(
                [:from, :year, :rep_period] =>
                    (from, y, rp) ->
                        (from, y, rp) == (row_inter.asset, row_map.year, row_map.rep_period),
                df_flows;
                view = true,
            )
            sub_df_flows.duration = length.(sub_df_flows.timesteps_block)
            if is_storage_level
                row_inter.outgoing_flow +=
                    LinearAlgebra.dot(
                        sub_df_flows.flow,
                        sub_df_flows.duration ./ sub_df_flows.efficiency,
                    ) * row_map.weight
            else
                row_inter.outgoing_flow +=
                    LinearAlgebra.dot(sub_df_flows.flow, sub_df_flows.duration) * row_map.weight
            end

            if is_storage_level
                sub_df_flows = filter(
                    [:to, :year, :rep_period] =>
                        (to, y, rp) ->
                            (to, y, rp) == (row_inter.asset, row_map.year, row_map.rep_period),
                    df_flows;
                    view = true,
                )
                sub_df_flows.duration = length.(sub_df_flows.timesteps_block)
                row_inter.incoming_flow +=
                    LinearAlgebra.dot(
                        sub_df_flows.flow,
                        sub_df_flows.duration .* sub_df_flows.efficiency,
                    ) * row_map.weight

                row_inter.inflows_profile_aggregation +=
                    profile_aggregation(
                        sum,
                        graph[row_inter.asset].rep_periods_profiles,
                        row_map.year,
                        row_map.year,
                        ("inflows", row_map.rep_period),
                        representative_periods[row_map.year][row_map.rep_period].timesteps,
                        0.0,
                    ) *
                    graph[row_inter.asset].storage_inflows[row_map.year] *
                    row_map.weight
            end
        end
    end
end

function add_expressions_to_dataframe!(
    dataframes,
    model,
    expression_workspace,
    representative_periods,
    timeframe,
    graph,
)
    @timeit to "add_expression_terms_to_df" begin
        df_is_charging = dataframes[:lowest_in_out] # This is explicitly marked because the df name and the variable name differ
        # This should be fixed after #884

        # Creating the incoming and outgoing flow expressions
        add_expression_terms_intra_rp_constraints!(
            dataframes[:lowest],
            dataframes[:flows],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = false,
            multiply_by_duration = true,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:lowest_storage_level_intra_rp],
            dataframes[:flows],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = false,
            multiply_by_duration = true,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_in_out],
            dataframes[:flows],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_in],
            dataframes[:flows],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_out],
            dataframes[:flows],
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
            add_min_outgoing_flow_duration = true,
        )
        if !isempty(dataframes[:units_on_and_outflows])
            add_expression_terms_intra_rp_constraints!(
                dataframes[:units_on_and_outflows],
                dataframes[:flows],
                expression_workspace,
                representative_periods,
                graph;
                use_highest_resolution = true,
                multiply_by_duration = false,
                add_min_outgoing_flow_duration = true,
            )
        end
        add_expression_terms_inter_rp_constraints!(
            dataframes[:storage_level_inter_rp],
            dataframes[:flows],
            timeframe.map_periods_to_rp,
            graph,
            representative_periods;
            is_storage_level = true,
        )
        add_expression_terms_inter_rp_constraints!(
            dataframes[:max_energy_inter_rp],
            dataframes[:flows],
            timeframe.map_periods_to_rp,
            graph,
            representative_periods,
        )
        add_expression_terms_inter_rp_constraints!(
            dataframes[:min_energy_inter_rp],
            dataframes[:flows],
            timeframe.map_periods_to_rp,
            graph,
            representative_periods,
        )
        add_expression_is_charging_terms_intra_rp_constraints!(
            dataframes[:highest_in],
            df_is_charging,
            expression_workspace,
        )
        add_expression_is_charging_terms_intra_rp_constraints!(
            dataframes[:highest_out],
            df_is_charging,
            expression_workspace,
        )
        if !isempty(dataframes[:units_on_and_outflows])
            add_expression_units_on_terms_intra_rp_constraints!(
                dataframes[:units_on_and_outflows],
                dataframes[:units_on],
                expression_workspace,
            )
        end

        incoming_flow_lowest_resolution =
            model[:incoming_flow_lowest_resolution] = dataframes[:lowest].incoming_flow
        outgoing_flow_lowest_resolution =
            model[:outgoing_flow_lowest_resolution] = dataframes[:lowest].outgoing_flow
        incoming_flow_lowest_storage_resolution_intra_rp =
            model[:incoming_flow_lowest_storage_resolution_intra_rp] =
                dataframes[:lowest_storage_level_intra_rp].incoming_flow
        outgoing_flow_lowest_storage_resolution_intra_rp =
            model[:outgoing_flow_lowest_storage_resolution_intra_rp] =
                dataframes[:lowest_storage_level_intra_rp].outgoing_flow
        incoming_flow_highest_in_out_resolution =
            model[:incoming_flow_highest_in_out_resolution] =
                dataframes[:highest_in_out].incoming_flow
        outgoing_flow_highest_in_out_resolution =
            model[:outgoing_flow_highest_in_out_resolution] =
                dataframes[:highest_in_out].outgoing_flow
        incoming_flow_highest_in_resolution =
            model[:incoming_flow_highest_in_resolution] = dataframes[:highest_in].incoming_flow
        outgoing_flow_highest_out_resolution =
            model[:outgoing_flow_highest_out_resolution] = dataframes[:highest_out].outgoing_flow
        incoming_flow_storage_inter_rp_balance =
            model[:incoming_flow_storage_inter_rp_balance] =
                dataframes[:storage_level_inter_rp].incoming_flow
        outgoing_flow_storage_inter_rp_balance =
            model[:outgoing_flow_storage_inter_rp_balance] =
                dataframes[:storage_level_inter_rp].outgoing_flow
        # Below, we drop zero coefficients, but probably we don't have any
        # (if the implementation is correct)
        JuMP.drop_zeros!.(incoming_flow_lowest_resolution)
        JuMP.drop_zeros!.(outgoing_flow_lowest_resolution)
        JuMP.drop_zeros!.(incoming_flow_lowest_storage_resolution_intra_rp)
        JuMP.drop_zeros!.(outgoing_flow_lowest_storage_resolution_intra_rp)
        JuMP.drop_zeros!.(incoming_flow_highest_in_out_resolution)
        JuMP.drop_zeros!.(outgoing_flow_highest_in_out_resolution)
        JuMP.drop_zeros!.(incoming_flow_highest_in_resolution)
        JuMP.drop_zeros!.(outgoing_flow_highest_out_resolution)
        JuMP.drop_zeros!.(incoming_flow_storage_inter_rp_balance)
        JuMP.drop_zeros!.(outgoing_flow_storage_inter_rp_balance)
    end

    return (
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
        incoming_flow_lowest_storage_resolution_intra_rp,
        outgoing_flow_lowest_storage_resolution_intra_rp,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
        incoming_flow_highest_in_resolution,
        outgoing_flow_highest_out_resolution,
        incoming_flow_storage_inter_rp_balance,
        outgoing_flow_storage_inter_rp_balance,
    )
end

function create_variables!(model, graph, dataframes, sets)
    @timeit to "create variables" begin
        df_flows = dataframes[:flows]
        df_units_on = dataframes[:units_on]
        df_is_charging = dataframes[:lowest_in_out]
        ### Flow variables
        flow =
            model[:flow] =
                df_flows.flow = [
                    @variable(
                        model,
                        base_name = "flow[($(row.from), $(row.to)), $(row.year), $(row.rep_period), $(row.timesteps_block)]"
                    ) for row in eachrow(df_flows)
                ]

        @variable(model, 0 ≤ flows_investment[y in sets.Y, (u, v) in sets.Fi[y]])

        ### Investment variables
        @variable(model, 0 ≤ assets_investment[y in sets.Y, a in sets.Ai[y]])  #number of installed asset units [N]
        @variable(
            model,
            0 ≤ assets_decommission_simple_method[
                y in sets.Y,
                a in sets.decommissionable_assets_using_simple_method,
            ]
        )  #number of decommission asset units [N]
        @variable(
            model,
            0 <= assets_decommission_compact_method[(
                a,
                y,
                v,
            ) in sets.decommission_set_using_compact_method]
        )  #number of decommission asset units [N]
        @variable(model, 0 ≤ flows_decommission_using_simple_method[y in sets.Y, (u, v) in sets.Ft])  #number of decommission flow units [N]

        @variable(model, 0 ≤ assets_investment_energy[y in sets.Y, a in sets.Ase[y]∩sets.Ai[y]])  #number of installed asset units for storage energy [N]
        @variable(
            model,
            0 ≤ assets_decommission_energy_simple_method[
                y in sets.Y,
                a in sets.Ase[y]∩sets.decommissionable_assets_using_simple_method,
            ]
        )  #number of decommission asset energy units [N]

        ### Unit commitment variables
        units_on =
            model[:units_on] =
                df_units_on.units_on = [
                    @variable(
                        model,
                        lower_bound = 0.0,
                        base_name = "units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
                    ) for row in eachrow(df_units_on)
                ]

        ### Variables for storage assets
        storage_level_intra_rp =
            model[:storage_level_intra_rp] = [
                @variable(
                    model,
                    lower_bound = 0.0,
                    base_name = "storage_level_intra_rp[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
                ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
            ]
        storage_level_inter_rp =
            model[:storage_level_inter_rp] = [
                @variable(
                    model,
                    lower_bound = 0.0,
                    base_name = "storage_level_inter_rp[$(row.asset),$(row.year),$(row.periods_block)]"
                ) for row in eachrow(dataframes[:storage_level_inter_rp])
            ]
        is_charging =
            model[:is_charging] =
                df_is_charging.is_charging = [
                    @variable(
                        model,
                        lower_bound = 0.0,
                        upper_bound = 1.0,
                        base_name = "is_charging[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
                    ) for row in eachrow(df_is_charging)
                ]

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
                v in sets.V_non_milestone &&
                a in sets.existing_assets_by_year_using_compact_method[y]
            ) && graph[a].investment_integer[y]
                JuMP.set_integer(assets_decommission_compact_method[(a, y, v)])
            end
        end

        for y in sets.Y, (u, v) in sets.Fi[y]
            if graph[u, v].investment_integer[y]
                JuMP.set_integer(flows_investment[y, (u, v)])
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

        ### Binary Charging Variables
        df_is_charging.use_binary_storage_method = [
            graph[row.asset].use_binary_storage_method[row.year] for row in eachrow(df_is_charging)
        ]

        sub_df_is_charging_binary = DataFrames.subset(
            df_is_charging,
            [:asset, :year] => DataFrames.ByRow((a, y) -> a in sets.Asb[y]),
            :use_binary_storage_method => DataFrames.ByRow(==("binary"));
            view = true,
        )

        for row in eachrow(sub_df_is_charging_binary)
            JuMP.set_binary(is_charging[row.index])
        end

        ### Integer Unit Commitment Variables
        for row in eachrow(df_units_on)
            if !(row.asset in sets.Auc_integer[row.year])
                continue
            end

            JuMP.set_integer(units_on[row.index])
        end
    end

    return
end
