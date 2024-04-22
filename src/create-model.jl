export create_model!, create_model, construct_dataframes

"""
    dataframes = construct_dataframes(
        graph,
        representative_periods,
        constraints_partitions,
        timeframe,
    )

Computes the data frames used to linearize the variables and constraints. These are used
internally in the model only.
"""
function construct_dataframes(graph, representative_periods, constraints_partitions, timeframe)
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
                    rp = rp,
                    timesteps_block = timesteps_block,
                    efficiency = graph[u, v].efficiency,
                ) for timesteps_block in graph[u, v].rep_periods_partitions[rp]
            ) for (u, v) in F, rp in RP
        ) |> Iterators.flatten,
    )
    dataframes[:flows].index = 1:size(dataframes[:flows], 1)

    for (key, partitions) in constraints_partitions
        if length(partitions) == 0
            # No data, but ensure schema is correct
            dataframes[key] = DataFrame(;
                asset = Symbol[],
                rp = Int[],
                timesteps_block = UnitRange{Int}[],
                index = Int[],
            )
            continue
        end

        # This construction should ensure the ordering of the time blocks for groups of (a, rp)
        df = DataFrame(
            (
                (
                    (asset = a, rp = rp, timesteps_block = timesteps_block) for
                    timesteps_block in partition
                ) for ((a, rp), partition) in partitions
            ) |> Iterators.flatten,
        )
        df.index = 1:size(df, 1)
        dataframes[key] = df
    end

    # Dataframe to store the storage level between (inter) representative period variable (e.g., seasonal storage)
    #
    dataframes[:storage_level_inter_rp] = DataFrame(
        (
            (
                (asset = a, periods_block = periods_block) for
                periods_block in graph[a].timeframe_partitions
            ) for a in A
        ) |> Iterators.flatten,
    )
    if size(dataframes[:storage_level_inter_rp], 1) == 0
        dataframes[:storage_level_inter_rp] =
            DataFrame(; asset = Symbol[], periods_block = PeriodsBlock[])
    end
    dataframes[:storage_level_inter_rp].index = 1:size(dataframes[:storage_level_inter_rp], 1)

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

    grouped_cons = DataFrames.groupby(df_cons, [:rp, :asset])

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
        grouped_flows = DataFrames.groupby(df_flows, [:rp, case.asset_match])
        for ((rp, asset), sub_df) in pairs(grouped_cons)
            if !haskey(grouped_flows, (rp, asset))
                continue
            end
            resolution = multiply_by_duration ? representative_periods[rp].resolution : 1.0
            for i in eachindex(workspace)
                workspace[i] = JuMP.AffExpr(0.0)
            end
            # Store the corresponding flow in the workspace
            for row in eachrow(grouped_flows[(rp, asset)])
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
    representative_periods,
)
    df_inter[!, :incoming_flow] .= JuMP.AffExpr(0.0)
    df_inter[!, :outgoing_flow] .= JuMP.AffExpr(0.0)
    df_inter[!, :inflows_profile_aggregation] .= JuMP.AffExpr(0.0)

    # Incoming, outgoing flows, and profile aggregation
    for row_inter in eachrow(df_inter)
        sub_df_map = filter(:period => in(row_inter.periods_block), df_map; view = true)

        for row_map in eachrow(sub_df_map)
            sub_df_flows = filter(
                [:to, :rp] => (to, rp) -> to == row_inter.asset && rp == row_map.rep_period,
                df_flows;
                view = true,
            )
            row_inter.incoming_flow +=
                LinearAlgebra.dot(sub_df_flows.flow, sub_df_flows.efficiency) * row_map.weight
            sub_df_flows = filter(
                [:from, :rp] =>
                    (from, rp) -> from == row_inter.asset && rp == row_map.rep_period,
                df_flows;
                view = true,
            )
            row_inter.outgoing_flow +=
                LinearAlgebra.dot(sub_df_flows.flow, sub_df_flows.efficiency) * row_map.weight
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
    energy_problem.dataframes =
        construct_dataframes(graph, representative_periods, constraints_partitions, timeframe)
    energy_problem.model =
        create_model(graph, representative_periods, energy_problem.dataframes, timeframe; kwargs...)
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
    # representative period `rp`.
    function duration(timesteps_block, rp)
        return length(timesteps_block) * representative_periods[rp].resolution
    end

    ## Sets unpacking
    A = MetaGraphsNext.labels(graph) |> collect
    F = MetaGraphsNext.edge_labels(graph) |> collect
    filter_assets(key, value) =
        filter(a -> !ismissing(getfield(graph[a], key)) && getfield(graph[a], key) == value, A)
    filter_flows(key, value) = filter(f -> getfield(graph[f...], key) == value, F)

    Ac  = filter_assets(:type, :consumer)
    Ap  = filter_assets(:type, :producer)
    As  = filter_assets(:type, :storage)
    Ah  = filter_assets(:type, :hub)
    Acv = filter_assets(:type, :conversion)
    Ft  = filter_flows(:is_transport, true)

    # Create subsets of assets by investable
    Ai = filter_assets(:investable, true)
    Fi = filter_flows(:investable, true)

    # Create subsets of assets by storage_method_energy
    Ase = filter_assets(:storage_method_energy, true)

    # Maximum timestep
    Tmax = maximum(last(rp.timesteps) for rp in representative_periods)
    expression_workspace = Vector{JuMP.AffExpr}(undef, Tmax)

    # Unpacking dataframes
    df_flows = dataframes[:flows]

    df_storage_intra_rp_balance_grouped =
        DataFrames.groupby(dataframes[:lowest_storage_level_intra_rp], [:asset, :rp])
    df_storage_inter_rp_balance_grouped =
        DataFrames.groupby(dataframes[:storage_level_inter_rp], [:asset])

    ## Model
    model = JuMP.Model()

    ## Variables
    flow =
        model[:flow] =
            df_flows.flow = [
                @variable(
                    model,
                    base_name = "flow[($(row.from), $(row.to)), $(row.rp), $(row.timesteps_block)]"
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
                base_name = "storage_level_intra_rp[$(row.asset),$(row.rp),$(row.timesteps_block)]"
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

    ## Expressions
    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        if storage_method_energy
            graph[a].capacity_storage_energy * assets_investment[a]
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
        representative_periods,
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
        model[:incoming_flow_highest_in_out_resolution] = dataframes[:highest_in_out].incoming_flow
    outgoing_flow_highest_in_out_resolution =
        model[:outgoing_flow_highest_in_out_resolution] = dataframes[:highest_in_out].outgoing_flow
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

    ## Expressions for the objective function
    assets_investment_cost = @expression(
        model,
        sum(graph[a].investment_cost * graph[a].capacity * assets_investment[a] for a in Ai)
    )

    flows_investment_cost = @expression(
        model,
        sum(
            graph[u, v].investment_cost * graph[u, v].capacity * flows_investment[(u, v)] for
            (u, v) in Fi
        )
    )

    flows_variable_cost = @expression(
        model,
        sum(
            representative_periods[row.rp].weight *
            duration(row.timesteps_block, row.rp) *
            graph[row.from, row.to].variable_cost *
            row.flow for row in eachrow(df_flows)
        )
    )

    ## Objective function
    @objective(model, Min, assets_investment_cost + flows_investment_cost + flows_variable_cost)

    ## Constraints
    add_capacity_constraints!(
        model,
        graph,
        dataframes,
        df_flows,
        flow,
        Ai,
        assets_investment,
        outgoing_flow_highest_out_resolution,
        incoming_flow_highest_in_resolution,
    )

    add_consumer_constraints!(
        model,
        graph,
        dataframes,
        Ac,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    add_storage_constraints!(
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

    add_hub_constraints!(
        model,
        dataframes,
        Ah,
        incoming_flow_highest_in_out_resolution,
        outgoing_flow_highest_in_out_resolution,
    )

    add_conversion_constraints!(
        model,
        dataframes,
        Acv,
        incoming_flow_lowest_resolution,
        outgoing_flow_lowest_resolution,
    )

    add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

    add_investment_constraints!(graph, Ai, Fi, assets_investment, flows_investment)

    if write_lp_file
        JuMP.write_to_file(model, "model.lp")
    end

    return model
end
