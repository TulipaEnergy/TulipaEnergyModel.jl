export create_model!, create_model, construct_dataframes

"""
    _get_graph_asset_or_flow(graph, a)
    _get_graph_asset_or_flow(graph, (u, v))

Returns `graph[a]` or `graph[u, v]`.
"""
_get_graph_asset_or_flow(graph, a) = graph[a]
_get_graph_asset_or_flow(graph, f::Tuple) = graph[f...]

"""
    get_graph_value_or_missing(graph, graph_key, field_key)
    get_graph_value_or_missing(graph, graph_key, field_key, year)

Get `graph[graph_key].field_key` (or `graph[graph_key].field_key[year]`) or return `missing` if
any of the values do not exist.
We also check if `graph[graph_key].active[year]` is true if the `year` is passed and return
`missing` otherwise.
"""
function get_graph_value_or_missing(graph, graph_key, field_key)
    g = _get_graph_asset_or_flow(graph, graph_key)
    return getproperty(g, field_key)
end
function get_graph_value_or_missing(graph, graph_key, field_key, year)
    g = get_graph_value_or_missing(graph, graph_key, field_key)
    if !_get_graph_asset_or_flow(graph, graph_key).active[year]
        return missing
    end
    return get(g, year, missing)
end

"""
    safe_comparison(graph, a, value, key)
    safe_comparison(graph, a, value, key, year)

Check if `graph[a].value` (or `graph[a].value[year]`) is equal to `value`.
This function assumes that if `graph[a].value` is a dictionary and `value` is not, then you made a mistake.
This makes it safer, because it will not silently return `false`.
It also checks for missing.
"""
function safe_comparison(graph, a, value1, args...)
    value2 = get_graph_value_or_missing(graph, a, args...)
    if ismissing(value1) || ismissing(value2)
        return false
    end
    return cmp(value1, value2) == 0 # Will error is one is a container (vector, dict) and the other is not
end

"""
    safe_inclusion(graph, a, value, key)
    safe_inclusion(graph, a, value, key, year)

Check if `graph[a].value` (or `graph[a].value[year]`) is in `values`.
This correctly check that `missing in [missing]` returns `false`.
"""
function safe_inclusion(graph, a, values::Vector, args...)
    value = get_graph_value_or_missing(graph, a, args...)
    return coalesce(value in values, false)
end

"""
    filter_graph(graph, elements, value, key)
    filter_graph(graph, elements, value, key, year)

Helper function to filter elements (assets or flows) in the graph given a key (and possibly year) and value (or values).
In the safest case, this is equivalent to the filters

```julia
filter_assets_whose_key_equal_to_value = a -> graph[a].key == value
filter_assets_whose_key_year_equal_to_value = a -> graph[a].key[year] in value
filter_flows_whose_key_equal_to_value = f -> graph[f...].key == value
filter_flows_whose_key_year_equal_to_value = f -> graph[f...].key[year] in value
```
"""
filter_graph(graph, elements, value, args...) =
    filter(e -> safe_comparison(graph, e, value, args...), elements)
filter_graph(graph, elements, values::Vector, args...) =
    filter(e -> safe_inclusion(graph, e, values, args...), elements)

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

"""
    profile_aggregation(agg, profiles, key, block, default_value)

Aggregates the `profiles[key]` over the `block` using the `agg` function.
If the profile does not exist, uses `default_value` instead of **each** profile value.

`profiles` should be a dictionary of profiles, for instance `graph[a].profiles` or `graph[u, v].profiles`.
If `profiles[key]` exists, then this function computes the aggregation of `profiles[key]`
over the range `block` using the aggregator `agg`, i.e., `agg(profiles[key][block])`.
If `profiles[key]` does not exist, then this substitutes it with a vector of `default_value`s.
"""
function profile_aggregation(agg, profiles, year, commission_year, key, block, default_value)
    if haskey(profiles, year) &&
       haskey(profiles[year], commission_year) &&
       haskey(profiles[year][commission_year], key)
        return agg(profiles[year][commission_year][key][block])
    else
        return agg(Iterators.repeated(default_value, length(block)))
    end
end

"""
    create_intervals(years)

Create a dictionary of intervals for `years`. The interval is assigned to the its starting year.
The last interval is 1.
"""
function create_intervals_for_years(years)
    intervals = Dict()

    # This assumes that `years` is ordered
    for i in 1:length(years)-1
        intervals[years[i]] = years[i+1] - years[i]
    end

    intervals[years[end]] = 1

    return intervals
end

"""
    create_model!(energy_problem; verbose = false)

Create the internal model of an [`TulipaEnergyModel.EnergyProblem`](@ref).
"""
function create_model!(energy_problem; kwargs...)
    elapsed_time_create_model = @elapsed begin
        graph = energy_problem.graph
        representative_periods = energy_problem.representative_periods
        constraints_partitions = energy_problem.constraints_partitions
        timeframe = energy_problem.timeframe
        groups = energy_problem.groups
        model_parameters = energy_problem.model_parameters
        years = energy_problem.years
        energy_problem.dataframes = @timeit to "construct_dataframes" construct_dataframes(
            graph,
            representative_periods,
            constraints_partitions,
            years,
        )
        energy_problem.model = @timeit to "create_model" create_model(
            graph,
            representative_periods,
            energy_problem.dataframes,
            years,
            timeframe,
            groups,
            model_parameters;
            kwargs...,
        )
        energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
        energy_problem.solved = false
        energy_problem.objective_value = NaN
    end

    energy_problem.timings["creating the model"] = elapsed_time_create_model

    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes, timeframe, groups; write_lp_file = false)

Create the energy model given the `graph`, `representative_periods`, dictionary of `dataframes` (created by [`construct_dataframes`](@ref)), timeframe, and groups.
"""
function create_model(
    graph,
    representative_periods,
    dataframes,
    years,
    timeframe,
    groups,
    model_parameters;
    write_lp_file = false,
)

    ## Helper functions
    # Computes the duration of the `block` and multiply by the resolution of the
    # representative period `rp`.
    function duration(timesteps_block, rp, representative_periods)
        return length(timesteps_block) * representative_periods[rp].resolution
    end

    Y = [year.id for year in years if year.is_milestone]
    V_all = [year.id for year in years]
    V_non_milestone = [year.id for year in years if !year.is_milestone]

    # Maximum timestep
    Tmax = maximum(last(rp.timesteps) for year in Y for rp in representative_periods[year])

    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    ## Sets unpacking
    @timeit to "unpacking and creating sets" begin
        A   = MetaGraphsNext.labels(graph) |> collect
        F   = MetaGraphsNext.edge_labels(graph) |> collect
        Ac  = filter_graph(graph, A, "consumer", :type)
        Ap  = filter_graph(graph, A, "producer", :type)
        As  = filter_graph(graph, A, "storage", :type)
        Ah  = filter_graph(graph, A, "hub", :type)
        Acv = filter_graph(graph, A, "conversion", :type)
        Ft  = filter_graph(graph, F, true, :is_transport)

        # Create subsets of assets by investable
        Ai = Dict(y => filter_graph(graph, A, true, :investable, y) for y in Y)
        Fi = Dict(y => filter_graph(graph, F, true, :investable, y) for y in Y)

        # Create a subset of years by investable assets, i.e., inverting Ai
        Yi = Dict(
            a => [y for y in Y if a in Ai[y]] for a in A if any(graph[a].investable[y] for y in Y)
        )

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
        # Cond2: either invested in non-milestone years (i.e., initial units), or invested in investable milestone years
        cond1_domain_decommission_variables(a, y, v) =
            starting_year_using_compact_method[y, a] ≤ v < y
        cond2_domain_decommission_variables(a, v) =
            (v in V_non_milestone && a in existing_assets_by_year_using_compact_method[v]) ||
            (v in Y && a in investable_assets_using_compact_method[v])

        decommission_set_using_compact_method = [
            (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
            v in V_all if cond1_domain_decommission_variables(a, y, v) &&
            cond2_domain_decommission_variables(a, v)
        ]

        accumulated_set_using_compact_method = [
            (a, y, v) for a in decommissionable_assets_using_compact_method for y in Y for
            v in V_all if starting_year_using_compact_method[y, a] ≤ v ≤ y && ((
                (v in V_non_milestone && a in existing_assets_by_year_using_compact_method[v]) || (v in Y)
            ))
        ]

        # Create a lookup set for compact method
        accumulated_set_using_compact_method_lookup = Dict(
            (a, y, v) => idx for
            (idx, (a, y, v)) in enumerate(accumulated_set_using_compact_method)
        )

        # Create subsets of storage assets
        Ase = Dict(y => As ∩ filter_graph(graph, A, true, :storage_method_energy, y) for y in Y)
        Asb = Dict(
            y =>
                As ∩ filter_graph(
                    graph,
                    A,
                    ["binary", "relaxed_binary"],
                    :use_binary_storage_method,
                    y,
                ) for y in Y
        )

        # Create subsets of assets for ramping and unit commitment for producers and conversion assets
        Ar = Dict(y => (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :ramping, y) for y in Y)
        Auc = Dict(y => (Ap ∪ Acv) ∩ filter_graph(graph, A, true, :unit_commitment, y) for y in Y)
        Auc_integer =
            Dict(y => Auc[y] ∩ filter_graph(graph, A, true, :unit_commitment_integer, y) for y in Y)
        Auc_basic = Dict(
            y => Auc[y] ∩ filter_graph(graph, A, "basic", :unit_commitment_method, y) for y in Y
        )
    end
    # Unpacking dataframes
    @timeit to "unpacking dataframes" begin
        df_flows = dataframes[:flows]
        df_is_charging = dataframes[:lowest_in_out]
        df_units_on = dataframes[:units_on]
        df_units_on_and_outflows = dataframes[:units_on_and_outflows]
        df_storage_intra_rp_balance_grouped = DataFrames.groupby(
            dataframes[:lowest_storage_level_intra_rp],
            [:asset, :rep_period, :year],
        )
        df_storage_inter_rp_balance_grouped =
            DataFrames.groupby(dataframes[:storage_level_inter_rp], [:asset, :year])
    end

    ## Model
    model = JuMP.Model()

    ## Variables
    @timeit to "create variables" begin
        ### Flow variables
        flow =
            model[:flow] =
                df_flows.flow = [
                    @variable(
                        model,
                        base_name = "flow[($(row.from), $(row.to)), $(row.year), $(row.rep_period), $(row.timesteps_block)]"
                    ) for row in eachrow(df_flows)
                ]

        @variable(model, 0 ≤ flows_investment[y in Y, (u, v) in Fi[y]])

        ### Investment variables
        @variable(model, 0 ≤ assets_investment[y in Y, a in Ai[y]])  #number of installed asset units [N]
        @variable(
            model,
            0 ≤ assets_decommission_simple_method[
                y in Y,
                a in decommissionable_assets_using_simple_method,
            ]
        )  #number of decommission asset units [N]
        @variable(
            model,
            0 <=
            assets_decommission_compact_method[(a, y, v) in decommission_set_using_compact_method]
        )  #number of decommission asset units [N]
        @variable(model, 0 ≤ flows_decommission_using_simple_method[y in Y, (u, v) in Ft])  #number of decommission flow units [N]

        @variable(model, 0 ≤ assets_investment_energy[y in Y, a in Ase[y]∩Ai[y]])  #number of installed asset units for storage energy [N]
        @variable(
            model,
            0 ≤ assets_decommission_energy_simple_method[
                y in Y,
                a in Ase[y]∩decommissionable_assets_using_simple_method,
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
        for y in Y, a in Ai[y]
            if graph[a].investment_integer[y]
                JuMP.set_integer(assets_investment[y, a])
            end
        end

        for y in Y, a in decommissionable_assets_using_simple_method
            if graph[a].investment_integer[y]
                JuMP.set_integer(assets_decommission_simple_method[y, a])
            end
        end

        for (a, y, v) in decommission_set_using_compact_method
            # We don't do anything with existing units (because it can be integers or non-integers)
            if !(v in V_non_milestone && a in existing_assets_by_year_using_compact_method[y]) &&
               graph[a].investment_integer[y]
                JuMP.set_integer(assets_decommission_compact_method[(a, y, v)])
            end
        end

        for y in Y, (u, v) in Fi[y]
            if graph[u, v].investment_integer[y]
                JuMP.set_integer(flows_investment[y, (u, v)])
            end
        end

        for y in Y, a in Ase[y] ∩ Ai[y]
            if graph[a].investment_integer_storage_energy[y]
                JuMP.set_integer(assets_investment_energy[y, a])
            end
        end

        for y in Y, a in Ase[y] ∩ decommissionable_assets_using_simple_method
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
            [:asset, :year] => DataFrames.ByRow((a, y) -> a in Asb[y]),
            :use_binary_storage_method => DataFrames.ByRow(==("binary"));
            view = true,
        )

        for row in eachrow(sub_df_is_charging_binary)
            JuMP.set_binary(is_charging[row.index])
        end

        ### Integer Unit Commitment Variables
        for row in eachrow(df_units_on)
            if !(row.asset in Auc_integer[row.year])
                continue
            end

            JuMP.set_integer(units_on[row.index])
        end
    end

    ## Add expressions to dataframes
    @timeit to "add_expression_terms_to_df" begin
        # Creating the incoming and outgoing flow expressions
        add_expression_terms_intra_rp_constraints!(
            dataframes[:lowest],
            df_flows,
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = false,
            multiply_by_duration = true,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:lowest_storage_level_intra_rp],
            df_flows,
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = false,
            multiply_by_duration = true,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_in_out],
            df_flows,
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_in],
            df_flows,
            expression_workspace,
            representative_periods,
            graph;
            use_highest_resolution = true,
            multiply_by_duration = false,
        )
        add_expression_terms_intra_rp_constraints!(
            dataframes[:highest_out],
            df_flows,
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
                df_flows,
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
            df_flows,
            timeframe.map_periods_to_rp,
            graph,
            representative_periods;
            is_storage_level = true,
        )
        add_expression_terms_inter_rp_constraints!(
            dataframes[:max_energy_inter_rp],
            df_flows,
            timeframe.map_periods_to_rp,
            graph,
            representative_periods,
        )
        add_expression_terms_inter_rp_constraints!(
            dataframes[:min_energy_inter_rp],
            df_flows,
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
                df_units_on,
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

    ## Expressions for multi-year investment
    @timeit to "multi-year investment" begin
        accumulated_initial_units = @expression(
            model,
            accumulated_initial_units[a in A, y in Y],
            sum(values(graph[a].initial_units[y]))
        )

        ### Expressions for multi-year investment simple method
        accumulated_investment_units_using_simple_method = @expression(
            model,
            accumulated_investment_units_using_simple_method[
                a ∈ decommissionable_assets_using_simple_method,
                y in Y,
            ],
            sum(
                assets_investment[yy, a] for
                yy in Y if a ∈ investable_assets_using_simple_method[yy] &&
                starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_using_simple_method[
                a ∈ decommissionable_assets_using_simple_method,
                y in Y,
            ],
            sum(
                assets_decommission_simple_method[yy, a] for
                yy in Y if starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_units_simple_method[a ∈ decommissionable_assets_using_simple_method, y ∈ Y],
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
            ) in accumulated_set_using_compact_method],
            sum(
                assets_decommission_compact_method[(a, yy, v)] for
                yy in Y if v ≤ yy ≤ y && (a, yy, v) in decommission_set_using_compact_method
            )
        )
        cond1(a, y, v) = a in existing_assets_by_year_using_compact_method[v]
        cond2(a, y, v) = v in Y && a in investable_assets_using_compact_method[v]
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
                end for (a, y, v) in accumulated_set_using_compact_method
            ]

        ### Expressions for multi-year investment for accumulated units no matter the method
        accumulated_units_lookup =
            Dict((a, y) => idx for (idx, (a, y)) in enumerate((aa, yy) for aa in A for yy in Y))

        accumulated_units =
            model[:accumulated_units] = JuMP.AffExpr[
                if a in decommissionable_assets_using_simple_method
                    @expression(model, accumulated_units_simple_method[a, y])
                elseif a in decommissionable_assets_using_compact_method
                    @expression(
                        model,
                        sum(
                            accumulated_units_compact_method[accumulated_set_using_compact_method_lookup[(
                                a,
                                y,
                                v,
                            )]] for
                            v in V_all if (a, y, v) in accumulated_set_using_compact_method
                        )
                    )
                else
                    @expression(model, sum(values(graph[a].initial_units[y])))
                end for a in A for y in Y
            ]
        ## Expressions for transport assets
        @expression(
            model,
            accumulated_investment_units_transport_using_simple_method[y ∈ Y, (u, v) ∈ Ft],
            sum(
                flows_investment[yy, (u, v)] for yy in Y if
                (u, v) ∈ Fi[yy] && starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_decommission_units_transport_using_simple_method[y ∈ Y, (u, v) ∈ Ft],
            sum(
                flows_decommission_using_simple_method[yy, (u, v)] for
                yy in Y if starting_year_flows_using_simple_method[(y, (u, v))] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_flows_export_units[y ∈ Y, (u, v) ∈ Ft],
            sum(values(graph[u, v].initial_export_units[y])) +
            accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
            accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
        )
        @expression(
            model,
            accumulated_flows_import_units[y ∈ Y, (u, v) ∈ Ft],
            sum(values(graph[u, v].initial_import_units[y])) +
            accumulated_investment_units_transport_using_simple_method[y, (u, v)] -
            accumulated_decommission_units_transport_using_simple_method[y, (u, v)]
        )
    end

    ## Expressions for storage assets
    @timeit to "add_expressions_for_storage" begin
        @expression(
            model,
            accumulated_energy_units_simple_method[
                y ∈ Y,
                a ∈ Ase[y]∩decommissionable_assets_using_simple_method,
            ],
            sum(values(graph[a].initial_storage_units[y])) + sum(
                assets_investment_energy[yy, a] for
                yy in Y if a ∈ (Ase[yy] ∩ investable_assets_using_simple_method[yy]) &&
                starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            ) - sum(
                assets_decommission_energy_simple_method[yy, a] for
                yy in Y if a ∈ Ase[yy] && starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
            )
        )
        @expression(
            model,
            accumulated_energy_capacity[y ∈ Y, a ∈ As],
            if graph[a].storage_method_energy[y] &&
               a ∈ Ase[y] ∩ decommissionable_assets_using_simple_method
                graph[a].capacity_storage_energy * accumulated_energy_units_simple_method[y, a]
            else
                (
                    graph[a].capacity_storage_energy *
                    sum(values(graph[a].initial_storage_units[y])) +
                    if a ∈ Ai[y] ∩ decommissionable_assets_using_simple_method
                        graph[a].energy_to_power_ratio[y] *
                        graph[a].capacity *
                        (
                            accumulated_investment_units_using_simple_method[a, y] -
                            accumulated_decommission_units_using_simple_method[a, y]
                        )
                    else
                        0.0
                    end
                )
            end
        )
    end

    ## Expressions for the objective function
    @timeit to "objective" begin
        # Create a dict of weights for assets investment discounts
        weight_for_assets_investment_discounts =
            calculate_weight_for_investment_discounts(graph, Y, Ai, A, model_parameters)

        # Create a dict of weights for flows investment discounts
        weight_for_flows_investment_discounts =
            calculate_weight_for_investment_discounts(graph, Y, Fi, Ft, model_parameters)

        # Create a dict of intervals for milestone years
        intervals_for_milestone_years = create_intervals_for_years(Y)

        # Create a dict of operation discounts only for milestone years
        operation_discounts_for_milestone_years = Dict(
            y => 1 / (1 + model_parameters.discount_rate)^(y - model_parameters.discount_year)
            for y in Y
        )

        # Create a dict of operation discounts for milestone years including in-between years
        weight_for_operation_discounts = Dict(
            y => operation_discounts_for_milestone_years[y] * intervals_for_milestone_years[y]
            for y in Y
        )

        assets_investment_cost = @expression(
            model,
            sum(
                weight_for_assets_investment_discounts[(y, a)] *
                graph[a].investment_cost[y] *
                graph[a].capacity *
                assets_investment[y, a] for y in Y for a in Ai[y]
            )
        )

        assets_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost[y] *
                graph[a].capacity *
                accumulated_units_simple_method[a, y] for y in Y for
                a in decommissionable_assets_using_simple_method
            ) + sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost[v] *
                graph[a].capacity *
                accm for (accm, (a, y, v)) in
                zip(accumulated_units_compact_method, accumulated_set_using_compact_method)
            )
        )

        storage_assets_energy_investment_cost = @expression(
            model,
            sum(
                weight_for_assets_investment_discounts[(y, a)] *
                graph[a].investment_cost_storage_energy[y] *
                graph[a].capacity_storage_energy *
                assets_investment_energy[y, a] for y in Y for a in Ase[y] ∩ Ai[y]
            )
        )

        storage_assets_energy_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] *
                graph[a].fixed_cost_storage_energy[y] *
                graph[a].capacity_storage_energy *
                accumulated_energy_units_simple_method[y, a] for y in Y for
                a in Ase[y] ∩ decommissionable_assets_using_simple_method
            )
        )

        flows_investment_cost = @expression(
            model,
            sum(
                weight_for_flows_investment_discounts[(y, (u, v))] *
                graph[u, v].investment_cost[y] *
                graph[u, v].capacity *
                flows_investment[y, (u, v)] for y in Y for (u, v) in Fi[y]
            )
        )

        flows_fixed_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[y] * graph[u, v].fixed_cost[y] / 2 *
                graph[u, v].capacity *
                (
                    accumulated_flows_export_units[y, (u, v)] +
                    accumulated_flows_import_units[y, (u, v)]
                ) for y in Y for (u, v) in Fi[y]
            )
        )

        flows_variable_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[row.year] *
                representative_periods[row.year][row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period, representative_periods[row.year]) *
                graph[row.from, row.to].variable_cost[row.year] *
                row.flow for row in eachrow(df_flows)
            )
        )

        units_on_cost = @expression(
            model,
            sum(
                weight_for_operation_discounts[row.year] *
                representative_periods[row.year][row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period, representative_periods[row.year]) *
                graph[row.asset].units_on_cost[row.year] *
                row.units_on for row in eachrow(df_units_on) if
                !ismissing(graph[row.asset].units_on_cost[row.year])
            )
        )

        ## Objective function
        @objective(
            model,
            Min,
            assets_investment_cost +
            assets_fixed_cost +
            storage_assets_energy_investment_cost +
            storage_assets_energy_fixed_cost +
            flows_investment_cost +
            flows_fixed_cost +
            flows_variable_cost +
            units_on_cost
        )
    end

    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        model,
        graph,
        dataframes,
        df_flows,
        flow,
        Y,
        Ai,
        decommissionable_assets_using_simple_method,
        decommissionable_assets_using_compact_method,
        V_all,
        accumulated_units_lookup,
        accumulated_set_using_compact_method_lookup,
        Asb,
        accumulated_initial_units,
        accumulated_investment_units_using_simple_method,
        accumulated_units,
        accumulated_units_compact_method,
        accumulated_set_using_compact_method,
        outgoing_flow_highest_out_resolution,
        incoming_flow_highest_in_resolution,
    )

    @timeit to "add_energy_constraints!" add_energy_constraints!(model, graph, dataframes)

    @timeit to "add_consumer_constraints!" add_consumer_constraints!(
        model,
        graph,
        dataframes,
        Ac,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_storage_constraints!" add_storage_constraints!(
        model,
        graph,
        dataframes,
        Ai,
        accumulated_energy_capacity,
        incoming_flow_lowest_storage_resolution_intra_rp,
        outgoing_flow_lowest_storage_resolution_intra_rp,
        df_storage_intra_rp_balance_grouped,
        df_storage_inter_rp_balance_grouped,
        storage_level_intra_rp,
        storage_level_inter_rp,
        incoming_flow_storage_inter_rp_balance,
        outgoing_flow_storage_inter_rp_balance,
    )

    @timeit to "add_hub_constraints!" add_hub_constraints!(
        model,
        dataframes,
        Ah,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    @timeit to "add_conversion_constraints!" add_conversion_constraints!(
        model,
        dataframes,
        Acv,
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
    )

    @timeit to "add_transport_constraints!" add_transport_constraints!(
        model,
        graph,
        df_flows,
        flow,
        Ft,
        accumulated_flows_export_units,
        accumulated_flows_import_units,
        flows_investment,
    )

    @timeit to "add_investment_constraints!" add_investment_constraints!(
        graph,
        Y,
        Ai,
        Ase,
        Fi,
        assets_investment,
        assets_investment_energy,
        flows_investment,
    )

    if !isempty(groups)
        @timeit to "add_group_constraints!" add_group_constraints!(
            model,
            graph,
            Y,
            Ai,
            assets_investment,
            groups,
        )
    end

    if !isempty(dataframes[:units_on_and_outflows])
        @timeit to "add_ramping_constraints!" add_ramping_constraints!(
            model,
            graph,
            df_units_on_and_outflows,
            df_units_on,
            dataframes[:highest_out],
            outgoing_flow_highest_out_resolution,
            accumulated_units_lookup,
            accumulated_units,
            Ai,
            Auc,
            Auc_basic,
            Ar,
        )
    end

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
