export create_model!, create_model, construct_dataframes, filter_assets, filter_flows

"""
    Helper function to filter assets in the graph given a key and value
"""
filter_assets(graph, assets, key, values) =
    filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) == values, assets)
filter_assets(graph, assets, key, values::Vector{String}) =
    filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) in values, assets)

"""
    Helper function to filter flows in the graph given a key and value
"""
filter_flows(graph, flows, key, values) = filter(f -> getfield(graph[f...], key) == values, flows)

"""
    dataframes = construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,
    )

Computes the data frames used to linearize the variables and constraints. These are used
internally in the model only.
"""
function construct_dataframes(graph, representative_periods, constraints_partitions)
    A = MetaGraphsNext.labels(graph) |> collect
    F = MetaGraphsNext.edge_labels(graph) |> collect
    RP = 1:length(representative_periods)

    # Create subsets of assets
    Ap  = filter_assets(graph, A, :type, "producer")
    Acv = filter_assets(graph, A, :type, "conversion")
    Auc = (Ap ∪ Acv) ∩ filter_assets(graph, A, :unit_commitment, true)

    # Output object
    dataframes = Dict{Symbol,DataFrame}()

    for (key, partitions) in constraints_partitions
        if length(partitions) == 0
            # No data, but ensure schema is correct
            dataframes[key] = DataFrame(;
                asset = String[],
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
                    (asset = a, rep_period = rp, timesteps_block = timesteps_block) for
                    timesteps_block in partition
                ) for ((a, rp), partition) in partitions
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
                    rep_period = rp,
                    timesteps_block = timesteps_block,
                    efficiency = graph[u, v].efficiency,
                ) for timesteps_block in graph[u, v].rep_periods_partitions[rp]
            ) for (u, v) in F, rp in RP
        ) |> Iterators.flatten,
    )
    dataframes[:flows].index = 1:size(dataframes[:flows], 1)

    # DataFrame to store the constraints that are in the units_on resolution
    dataframes[:units_on] = DataFrame(
        (
            (
                (asset = a, rep_period = rp, timesteps_block = timesteps_block) for
                timesteps_block in graph[a].rep_periods_partitions[rp]
            ) for a in Auc, rp in RP
        ) |> Iterators.flatten,
    )
    dataframes[:units_on].index = 1:size(dataframes[:units_on], 1)

    # DataFrame to store the constraints that are in the highest resolution between units_on and the outgoing_flows
    dataframes[:units_on_and_outflows] = DataFrame(
        (
            (
                (asset = a, rep_period = rp, timesteps_block = timesteps_block) for
                timesteps_block in graph[a].rep_periods_partitions[rp]
            ) for a in Auc, rp in RP
        ) |> Iterators.flatten,
    )
    dataframes[:units_on_and_outflows].index = 1:size(dataframes[:units_on_and_outflows], 1)

    # Dataframe to store the storage level between (inter) representative period variable (e.g., seasonal storage)
    # Only for storage assets
    dataframes[:storage_level_inter_rp] =
        _construct_inter_rp_dataframes(A, graph, a -> a.type == "storage")

    # Dataframe to store the constraints for assets with maximum energy between (inter) representative periods
    # Only for assets with max energy limit
    dataframes[:max_energy_inter_rp] =
        _construct_inter_rp_dataframes(A, graph, a -> !ismissing(a.max_energy_timeframe_partition))

    # Dataframe to store the constraints for assets with minimum energy between (inter) representative periods
    # Only for assets with min energy limit
    dataframes[:min_energy_inter_rp] =
        _construct_inter_rp_dataframes(A, graph, a -> !ismissing(a.min_energy_timeframe_partition))

    return dataframes
end

"""
    df = _construct_inter_rp_dataframes(assets, graph, asset_filter)

Constructs dataframes for inter representative period constraints.

# Arguments
- `assets`: An array of assets.
- `graph`: The energy problem graph with the assets data.
- `asset_filter`: A function that filters assets based on certain criteria.

# Returns
A dataframe containing the constructed dataframe for constraints.

"""
function _construct_inter_rp_dataframes(assets, graph, asset_filter)
    df = DataFrame(
        (
            (
                (asset = a, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions
            ) for a in assets if asset_filter(graph[a])
        ) |> Iterators.flatten,
    )
    if size(df, 1) == 0
        df = DataFrame(; asset = String[], periods_block = PeriodsBlock[])
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
)
    # Aggregating function: If the duration should NOT be taken into account, we have to compute unique appearances of the flows.
    # Otherwise, just use the sum
    agg = multiply_by_duration ? v -> sum(v) : v -> sum(unique(v))

    grouped_cons = DataFrames.groupby(df_cons, [:rep_period, :asset])

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
        grouped_flows = DataFrames.groupby(df_flows, [:rep_period, case.asset_match])
        for ((rep_period, asset), sub_df) in pairs(grouped_cons)
            if !haskey(grouped_flows, (rep_period, asset))
                continue
            end
            resolution = multiply_by_duration ? representative_periods[rep_period].resolution : 1.0
            for i in eachindex(workspace)
                workspace[i] = JuMP.AffExpr(0.0)
            end
            # Store the corresponding flow in the workspace
            for row in eachrow(grouped_flows[(rep_period, asset)])
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
                end
            end
            # Sum the corresponding flows from the workspace
            for row in eachrow(sub_df)
                row[case.col_name] = agg(@view workspace[row.timesteps_block])
            end
        end
    end
end

"""
add_expression_is_charging_terms_intra_rp_constraints!(df_cons,
                                                       df_is_charging,
                                                       workspace
                                                       )

Computes the is_charging expressions per row of df_cons for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23
"""
function add_expression_is_charging_terms_intra_rp_constraints!(df_cons, df_is_charging, workspace)
    # Aggregating function: We have to compute the proportion of each variable is_charging in the constraint timesteps_block.
    agg = Statistics.mean

    grouped_cons = DataFrames.groupby(df_cons, [:rep_period, :asset])

    df_cons[!, :is_charging] .= JuMP.AffExpr(0.0)
    grouped_is_charging = DataFrames.groupby(df_is_charging, [:rep_period, :asset])
    for ((rep_period, asset), sub_df) in pairs(grouped_cons)
        if !haskey(grouped_is_charging, (rep_period, asset))
            continue
        end

        for i in eachindex(workspace)
            workspace[i] = JuMP.AffExpr(0.0)
        end
        # Store the corresponding variables in the workspace
        for row in eachrow(grouped_is_charging[(rep_period, asset)])
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
    add_expression_is_charging_terms_intra_rp_constraints!(
        df_cons,
        df_is_charging,
        workspace,
    )

Computes the is_charging expressions per row of df_cons for the constraints
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

    # Incoming, outgoing flows, and profile aggregation
    for row_inter in eachrow(df_inter)
        sub_df_map = filter(:period => in(row_inter.periods_block), df_map; view = true)

        for row_map in eachrow(sub_df_map)
            sub_df_flows = filter(
                [:from, :rep_period] =>
                    (from, rp) -> from == row_inter.asset && rp == row_map.rep_period,
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
                    [:to, :rep_period] =>
                        (to, rp) -> to == row_inter.asset && rp == row_map.rep_period,
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
                        ("inflows", row_map.rep_period),
                        representative_periods[row_map.rep_period].timesteps,
                        0.0,
                    ) *
                    graph[row_inter.asset].storage_inflows *
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
function profile_aggregation(agg, profiles, key, block, default_value)
    if haskey(profiles, key)
        return agg(profiles[key][block])
    else
        return agg(Iterators.repeated(default_value, length(block)))
    end
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
        energy_problem.dataframes = @timeit to "construct_dataframes" construct_dataframes(
            graph,
            representative_periods,
            constraints_partitions,
        )
        energy_problem.model = @timeit to "create_model" create_model(
            graph,
            representative_periods,
            energy_problem.dataframes,
            timeframe,
            groups;
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
    timeframe,
    groups;
    write_lp_file = false,
)

    ## Helper functions
    # Computes the duration of the `block` and multiply by the resolution of the
    # representative period `rp`.
    function duration(timesteps_block, rp)
        return length(timesteps_block) * representative_periods[rp].resolution
    end
    # Maximum timestep
    Tmax = maximum(last(rp.timesteps) for rp in representative_periods)
    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    ## Sets unpacking
    @timeit to "unpacking and creating sets" begin
        A = MetaGraphsNext.labels(graph) |> collect
        F = MetaGraphsNext.edge_labels(graph) |> collect

        Ac  = filter_assets(graph, A, :type, "consumer")
        Ap  = filter_assets(graph, A, :type, "producer")
        As  = filter_assets(graph, A, :type, "storage")
        Ah  = filter_assets(graph, A, :type, "hub")
        Acv = filter_assets(graph, A, :type, "conversion")
        Ft  = filter_flows(graph, F, :is_transport, true)

        # Create subsets of assets by investable
        Ai = filter_assets(graph, A, :investable, true)
        Fi = filter_flows(graph, F, :investable, true)

        # Create subsets of storage assets
        Ase = As ∩ filter_assets(graph, A, :storage_method_energy, true)
        Asb = As ∩ filter_assets(graph, A, :use_binary_storage_method, ["binary", "relaxed_binary"])

        # Create subsets of assets for ramping and unit commitment for producers and conversion assets
        Ar = (Ap ∪ Acv) ∩ filter_assets(graph, A, :ramping, true)
        Auc = (Ap ∪ Acv) ∩ filter_assets(graph, A, :unit_commitment, true)
        Auc_integer = Auc ∩ filter_assets(graph, A, :unit_commitment_integer, true)
        Auc_basic = Auc ∩ filter_assets(graph, A, :unit_commitment_method, "basic")
    end
    # Unpacking dataframes
    @timeit to "unpacking dataframes" begin
        df_flows = dataframes[:flows]
        df_is_charging = dataframes[:lowest_in_out]
        df_units_on = dataframes[:units_on]
        df_units_on_and_outflows = dataframes[:units_on_and_outflows]
        df_storage_intra_rp_balance_grouped =
            DataFrames.groupby(dataframes[:lowest_storage_level_intra_rp], [:asset, :rep_period])
        df_storage_inter_rp_balance_grouped =
            DataFrames.groupby(dataframes[:storage_level_inter_rp], [:asset])
    end

    ## Model
    model = JuMP.Model()

    ## Variables
    @timeit to "create variables" begin
        flow =
            model[:flow] =
                df_flows.flow = [
                    @variable(
                        model,
                        base_name = "flow[($(row.from), $(row.to)), $(row.rep_period), $(row.timesteps_block)]"
                    ) for row in eachrow(df_flows)
                ]
        @variable(model, 0 ≤ assets_investment[Ai])  #number of installed asset units [N]
        @variable(model, 0 ≤ flows_investment[Fi])
        @variable(model, 0 ≤ assets_investment_energy[Ase∩Ai])  #number of installed asset units for storage energy [N]

        units_on =
            model[:units_on] =
                df_units_on.units_on = [
                    @variable(
                        model,
                        lower_bound = 0.0,
                        base_name = "units_on[$(row.asset), $(row.rep_period), $(row.timesteps_block)]"
                    ) for row in eachrow(df_units_on)
                ]
        storage_level_intra_rp =
            model[:storage_level_intra_rp] = [
                @variable(
                    model,
                    lower_bound = 0.0,
                    base_name = "storage_level_intra_rp[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
                ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
            ]
        storage_level_inter_rp =
            model[:storage_level_inter_rp] = [
                @variable(
                    model,
                    lower_bound = 0.0,
                    base_name = "storage_level_inter_rp[$(row.asset),$(row.periods_block)]"
                ) for row in eachrow(dataframes[:storage_level_inter_rp])
            ]
        is_charging =
            model[:is_charging] =
                df_is_charging.is_charging = [
                    @variable(
                        model,
                        lower_bound = 0.0,
                        upper_bound = 1.0,
                        base_name = "is_charging[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
                    ) for row in eachrow(df_is_charging)
                ]

        ### Integer Investment Variables
        for a in Ai
            if graph[a].investment_integer
                JuMP.set_integer(assets_investment[a])
            end
        end

        for (u, v) in Fi
            if graph[u, v].investment_integer
                JuMP.set_integer(flows_investment[(u, v)])
            end
        end

        for a in Ase ∩ Ai
            if graph[a].investment_integer_storage_energy
                JuMP.set_integer(assets_investment_energy[a])
            end
        end

        ### Binary Charging Variables
        df_is_charging.use_binary_storage_method =
            [graph[a].use_binary_storage_method for a in df_is_charging.asset]
        sub_df_is_charging_binary = DataFrames.subset(
            df_is_charging,
            :asset => DataFrames.ByRow(in(Asb)),
            :use_binary_storage_method => DataFrames.ByRow(==("binary"));
            view = true,
        )

        for row in eachrow(sub_df_is_charging_binary)
            JuMP.set_binary(is_charging[row.index])
        end

        ### Integer Unit Commitment Variables
        if !isempty(Auc_integer)
            sub_df_units_on_integer = DataFrames.subset(
                df_units_on,
                :asset => DataFrames.ByRow(in(Auc_integer));
                view = true,
            )

            for row in eachrow(sub_df_units_on_integer)
                JuMP.set_integer(units_on[row.index])
            end
        end
    end

    ## Expressions
    @timeit to "add_expression_terms" begin
        @expression(
            model,
            energy_limit[a ∈ As∩Ai],
            if graph[a].storage_method_energy
                graph[a].capacity_storage_energy * assets_investment_energy[a]
            else
                graph[a].energy_to_power_ratio * graph[a].capacity * assets_investment[a]
            end
        )

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

    ## Expressions for the objective function
    @timeit to "objective" begin
        assets_investment_cost = @expression(
            model,
            sum(graph[a].investment_cost * graph[a].capacity * assets_investment[a] for a in Ai) + sum(
                graph[a].investment_cost_storage_energy *
                graph[a].capacity_storage_energy *
                assets_investment_energy[a] for a in Ase ∩ Ai
            )
        )

        flows_investment_cost = @expression(
            model,
            sum(
                graph[u, v].investment_cost * graph[u, v].capacity * flows_investment[(u, v)]
                for (u, v) in Fi
            )
        )

        flows_variable_cost = @expression(
            model,
            sum(
                representative_periods[row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period) *
                graph[row.from, row.to].variable_cost *
                row.flow for row in eachrow(df_flows)
            )
        )

        units_on_cost = @expression(
            model,
            sum(
                representative_periods[row.rep_period].weight *
                duration(row.timesteps_block, row.rep_period) *
                graph[row.asset].units_on_cost *
                row.units_on for
                row in eachrow(df_units_on) if !ismissing(graph[row.asset].units_on_cost)
            )
        )

        ## Objective function
        @objective(
            model,
            Min,
            assets_investment_cost + flows_investment_cost + flows_variable_cost + units_on_cost
        )
    end

    ## Constraints
    @timeit to "add_capacity_constraints!" add_capacity_constraints!(
        model,
        graph,
        dataframes,
        df_flows,
        flow,
        Ai,
        Asb,
        assets_investment,
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
        energy_limit,
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
        flows_investment,
    )

    @timeit to "add_investment_constraints!" add_investment_constraints!(
        graph,
        Ai,
        Ase,
        Fi,
        assets_investment,
        assets_investment_energy,
        flows_investment,
    )

    @timeit to "add_group_constraints!" add_group_constraints!(
        model,
        graph,
        Ai,
        assets_investment,
        groups,
    )

    if !isempty(dataframes[:units_on_and_outflows])
        @timeit to "add_ramping_constraints!" add_ramping_constraints!(
            model,
            graph,
            df_units_on_and_outflows,
            df_units_on,
            dataframes[:highest_out],
            outgoing_flow_highest_out_resolution,
            assets_investment,
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
