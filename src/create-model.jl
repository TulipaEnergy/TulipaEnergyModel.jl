export create_model!, create_model, construct_dataframes

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

    # Output object
    dataframes = Dict{Symbol,DataFrame}()

    # DataFrame to store the flow variables
    dataframes[:flows] = DataFrame(
        (
            (
                (
                    from = u,
                    to = v,
                    rep_period = rep_period,
                    timesteps_block = timesteps_block,
                    efficiency = graph[u, v].efficiency,
                ) for timesteps_block in graph[u, v].rep_periods_partitions[rep_period]
            ) for (u, v) in F, rep_period in RP
        ) |> Iterators.flatten,
    )
    dataframes[:flows].index = 1:size(dataframes[:flows], 1)

    for (key, partitions) in constraints_partitions
        if length(partitions) == 0
            # No data, but ensure schema is correct
            dataframes[key] = DataFrame(;
                asset = Symbol[],
                rep_period = Int[],
                timesteps_block = UnitRange{Int}[],
                index = Int[],
            )
            continue
        end

        # This construction should ensure the ordering of the time blocks for groups of (a, rep_period)
        df = DataFrame(
            (
                (
                    (asset = a, rep_period = rep_period, timesteps_block = timesteps_block) for
                    timesteps_block in partition
                ) for ((a, rep_period), partition) in partitions
            ) |> Iterators.flatten,
        )
        df.index = 1:size(df, 1)
        dataframes[key] = df
    end

    # Dataframe to store the storage level between (inter) representative period variable (e.g., seasonal storage)
    # Only for storage assets
    dataframes[:storage_level_inter_rp] = DataFrame(
        (
            (
                (asset = a, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions
            ) for a in A if graph[a].type == :storage
        ) |> Iterators.flatten,
    )
    if size(dataframes[:storage_level_inter_rp], 1) == 0
        dataframes[:storage_level_inter_rp] =
            DataFrame(; asset = Symbol[], periods_block = PeriodsBlock[])
    end
    dataframes[:storage_level_inter_rp].index = 1:size(dataframes[:storage_level_inter_rp], 1)

    # Dataframe to store the constraints for assets with maximum energy between (inter) representative periods
    # Only for assets with max energy limit
    dataframes[:max_energy_inter_rp] = DataFrame(
        (
            (
                (asset = a, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions
            ) for a in A if !ismissing(graph[a].max_energy_timeframe_partition)
        ) |> Iterators.flatten,
    )
    if size(dataframes[:max_energy_inter_rp], 1) == 0
        dataframes[:max_energy_inter_rp] =
            DataFrame(; asset = Symbol[], periods_block = PeriodsBlock[])
    end
    dataframes[:max_energy_inter_rp].index = 1:size(dataframes[:max_energy_inter_rp], 1)

    # Dataframe to store the constraints for assets with minimum energy between (inter) representative periods
    # Only for assets with min energy limit
    dataframes[:min_energy_inter_rp] = DataFrame(
        (
            (
                (asset = a, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions
            ) for a in A if !ismissing(graph[a].min_energy_timeframe_partition)
        ) |> Iterators.flatten,
    )
    if size(dataframes[:min_energy_inter_rp], 1) == 0
        dataframes[:min_energy_inter_rp] =
            DataFrame(; asset = Symbol[], periods_block = PeriodsBlock[])
    end
    dataframes[:min_energy_inter_rp].index = 1:size(dataframes[:min_energy_inter_rp], 1)

    return dataframes
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
        (col_name = :incoming_flow, asset_match = :to, selected_assets = [:hub, :consumer]),
        (
            col_name = :outgoing_flow,
            asset_match = :from,
            selected_assets = [:hub, :consumer, :producer],
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
                    (from, rep_period) ->
                        from == row_inter.asset && rep_period == row_map.rep_period,
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
                        (to, rep_period) ->
                            to == row_inter.asset && rep_period == row_map.rep_period,
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
                        (:inflows, row_map.rep_period),
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
    graph = energy_problem.graph
    representative_periods = energy_problem.representative_periods
    constraints_partitions = energy_problem.constraints_partitions
    timeframe = energy_problem.timeframe
    energy_problem.dataframes = @timeit to "construct_dataframes" construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,
    )
    energy_problem.model = @timeit to "create_model" create_model(
        graph,
        representative_periods,
        energy_problem.dataframes,
        timeframe;
        kwargs...,
    )
    energy_problem.termination_status = JuMP.OPTIMIZE_NOT_CALLED
    energy_problem.solved = false
    energy_problem.objective_value = NaN
    return energy_problem
end

"""
    model = create_model(graph, representative_periods, dataframes, timeframe; write_lp_file = false)

Create the energy model given the `graph`, `representative_periods`, dictionary of `dataframes` (created by [`construct_dataframes`](@ref)), and timeframe.
"""
function create_model(graph, representative_periods, dataframes, timeframe; write_lp_file = false)

    ## Helper functions
    # Computes the duration of the `block` and multiply by the resolution of the
    # representative period `rep_period`.
    function duration(timesteps_block, rep_period)
        return length(timesteps_block) * representative_periods[rep_period].resolution
    end
    # Maximum timestep
    Tmax = maximum(last(rep_period.timesteps) for rep_period in representative_periods)
    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    ## Sets unpacking
    @timeit to "unpacking and creating sets" begin
        A = MetaGraphsNext.labels(graph) |> collect
        F = MetaGraphsNext.edge_labels(graph) |> collect
        filter_assets(key, values) =
            filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) == values, A)
        filter_assets(key, values::Vector{Symbol}) =
            filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) in values, A)
        filter_flows(key, values) = filter(f -> getfield(graph[f...], key) == values, F)

        Ac  = filter_assets(:type, :consumer)
        Ap  = filter_assets(:type, :producer)
        As  = filter_assets(:type, :storage)
        Ah  = filter_assets(:type, :hub)
        Acv = filter_assets(:type, :conversion)
        Ft  = filter_flows(:is_transport, true)

        # Create subsets of assets by investable
        Ai = filter_assets(:investable, true)
        Fi = filter_flows(:investable, true)

        # Create subsets of storage assets
        Ase = As ∩ filter_assets(:storage_method_energy, true)
        Asb = As ∩ filter_assets(:use_binary_storage_method, [:binary, :relaxed_binary])
    end

    # Unpacking dataframes
    @timeit to "unpacking dataframes" begin
        df_flows = dataframes[:flows]
        df_is_charging = dataframes[:lowest_in_out]

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

        df_is_charging.use_binary_storage_method =
            [graph[a].use_binary_storage_method for a in df_is_charging.asset]
        sub_df_is_charging_binary = DataFrames.subset(
            df_is_charging,
            :asset => DataFrames.ByRow(in(Asb)),
            :use_binary_storage_method => DataFrames.ByRow(==(:binary));
            view = true,
        )

        for row in eachrow(sub_df_is_charging_binary)
            JuMP.set_binary(is_charging[row.index])
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

        ## Objective function
        @objective(model, Min, assets_investment_cost + flows_investment_cost + flows_variable_cost)
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

    if write_lp_file
        @timeit to "write lp file" JuMP.write_to_file(model, "model.lp")
    end

    return model
end
