# Tools to prepare data and structures to the model creation
export create_sets, prepare_profiles_structure

"""
    add_expression_terms_rep_period_constraints!(df_cons,
                                               df_flows,
                                               workspace;
                                               use_highest_resolution = true,
                                               multiply_by_duration = true,
                                               add_min_outgoing_flow_duration = false,
                                               )

Computes the incoming and outgoing expressions per row of df_cons for the constraints
that are within (intra) the representative periods.

This function is only used internally in the model.

This strategy is based on the replies in this discourse thread:

  - https://discourse.julialang.org/t/help-improving-the-speed-of-a-dataframes-operation/107615/23

# Implementation

This expression computation uses a workspace to store all variables defined for
each timestep.
The idea of this algorithm is to append all variables defined at time
`timestep` in `workspace[timestep]` and then aggregate then for the constraint
time block.

The algorithm works like this:

1. Loop over each group of (asset, year, rep_period)
1.1. Loop over each variable in the group: (var_idx, var_time_block_start, var_time_block_end)
1.1.1. Loop over each timestep in var_time_block_start:var_time_block_end
1.1.1.1. Compute the coefficient of the variable based on the rep_period
  resolution and the variable efficiency
1.1.1.2. Store (var_idx, coefficient) in workspace[timestep]
1.2. Loop over each constraint in the group: (cons_idx, cons_time_block_start, cons_time_block_end)
1.2.1. Aggregate all variables in workspace[timestep] for timestep in the time
  block to create a list of variable indices and their coefficients [(var_idx1, coef1), ...]
1.2.2. Compute the expression using the variable container, the indices and coefficients

Notes:
- On step 1.2.1, the aggregation can be either by uniqueness of not, i.e., if
  the variable happens in more that one `workspace[timestep]`, should we add up
  the coefficients or not. This is defined by the keyword
`multiply_by_duration`
"""
function add_expression_terms_rep_period_constraints!(
    connection,
    cons::TulipaConstraint,
    flow::TulipaVariable;
    use_highest_resolution = true,
    multiply_by_duration = true,
    add_min_outgoing_flow_duration = false,
)
    # cons' asset will be matched with flow's to or from, depending on whether
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
    # TODO: Move this new workspace definition out of this function if and when it's used by other functions
    Tmax = only(
        row[1] for
        row in DuckDB.query(connection, "SELECT MAX(num_timesteps) FROM rep_periods_data")
    )::Int32

    workspace = [Dict{Int,Float64}() for _ in 1:Tmax]

    # The SQL strategy to improve looping over the groups and then the
    # constraints and variables, is to create grouped tables beforehand and join them
    # The grouped constraint table is created below
    grouped_cons_table_name = "t_grouped_$(cons.table_name)"
    if !_check_if_table_exists(connection, grouped_cons_table_name)
        DuckDB.query(
            connection,
            "CREATE TEMP TABLE $grouped_cons_table_name AS
            SELECT
                cons.asset,
                cons.year,
                cons.rep_period,
                ARRAY_AGG(cons.index ORDER BY cons.index) AS index,
                ARRAY_AGG(cons.time_block_start ORDER BY cons.index) AS time_block_start,
                ARRAY_AGG(cons.time_block_end ORDER BY cons.index) AS time_block_end,
            FROM $(cons.table_name) AS cons
            GROUP BY cons.asset, cons.year, cons.rep_period
            ",
        )
    end

    for case in cases
        attach_expression!(cons, case.expr_key, Vector{JuMP.AffExpr}(undef, num_rows))
        cons.expressions[case.expr_key] .= JuMP.AffExpr(0.0)
        conditions_to_add_min_outgoing_flow_duration =
            add_min_outgoing_flow_duration && case.expr_key == :outgoing
        if conditions_to_add_min_outgoing_flow_duration
            # TODO: Evaluate what to do with this
            # Originally, this was a column attach to the indices Assuming the
            # indices will be DuckDB tables, that would be problematic,
            # although possible However, that would be the only place that
            # DuckDB tables are changed after creation - notice that
            # constraints create new tables when a new column is necessary The
            # current solution is to attach as a coefficient, a new field of
            # TulipaConstraint created just for this purpose
            attach_coefficient!(cons, :min_outgoing_flow_duration, ones(num_rows))
        end

        # The grouped variable table is created below for each case (from=asset, to=asset)
        grouped_var_table_name = "t_grouped_$(flow.table_name)_match_on_$(case.asset_match)"
        if !_check_if_table_exists(connection, grouped_var_table_name)
            DuckDB.query(
                connection,
                "CREATE TEMP TABLE $grouped_var_table_name AS
                SELECT
                    var.$(case.asset_match) AS asset,
                    var.year,
                    var.rep_period,
                    ARRAY_AGG(var.index ORDER BY var.index) AS index,
                    ARRAY_AGG(var.time_block_start ORDER BY var.index) AS time_block_start,
                    ARRAY_AGG(var.time_block_end ORDER BY var.index) AS time_block_end,
                    ARRAY_AGG(var.efficiency ORDER BY var.index) AS efficiency,
                FROM $(flow.table_name) AS var
                GROUP BY var.$(case.asset_match), var.year, var.rep_period
                ",
            )
        end

        resolution_query = multiply_by_duration ? "rep_periods_data.resolution" : "1.0::FLOAT8"

        # Start of the algorithm
        # 1. Loop over each group of (asset, year, rep_period)
        for group_row in DuckDB.query(
            connection,
            "SELECT
                cons.asset,
                cons.year,
                cons.rep_period,
                cons.index AS cons_idx,
                cons.time_block_start AS cons_time_block_start,
                cons.time_block_end AS cons_time_block_end,
                var.index AS var_idx,
                var.time_block_start AS var_time_block_start,
                var.time_block_end AS var_time_block_end,
                var.efficiency,
                asset.type AS type,
                $resolution_query AS resolution,
            FROM $grouped_cons_table_name AS cons
            LEFT JOIN $grouped_var_table_name AS var
                ON cons.asset = var.asset
                AND cons.year = var.year
                AND cons.rep_period = var.rep_period
            LEFT JOIN asset
                ON cons.asset = asset.asset
            LEFT JOIN rep_periods_data
                ON cons.rep_period = rep_periods_data.rep_period
                AND cons.year = rep_periods_data.year
            WHERE
                len(var.index) > 0
            ",
        )
            resolution = group_row.resolution::Float64
            empty!.(workspace)
            outgoing_flow_durations = typemax(Int64) #LARGE_NUMBER to start finding the minimum outgoing flow duration

            # Step 1.1. Loop over each variable in the group
            for (var_idx, time_block_start, time_block_end, efficiency) in zip(
                group_row.var_idx::Vector{Union{Missing,Int64}},
                group_row.var_time_block_start::Vector{Union{Missing,Int32}},
                group_row.var_time_block_end::Vector{Union{Missing,Int32}},
                group_row.efficiency::Vector{Union{Missing,Float64}},
            )
                time_block = time_block_start:time_block_end
                # Step 1.1.1.
                for timestep in time_block
                    # Step 1.1.1.1.
                    # Set the efficiency to 1 for inflows and outflows of hub and consumer assets, and outflows for producer assets
                    # And when you want the highest resolution (which is asset type-agnostic)
                    efficiency_coefficient =
                        if group_row.type::String in case.selected_assets || use_highest_resolution
                            1.0
                        else
                            if case.expr_key == :incoming
                                efficiency::Float64
                            else
                                # Divide by efficiency for outgoing flows
                                1.0 / efficiency::Float64
                            end
                        end
                    # Step 1.1.1.2.
                    workspace[timestep][var_idx] = resolution * efficiency_coefficient
                end
                if conditions_to_add_min_outgoing_flow_duration
                    outgoing_flow_durations =
                        min(outgoing_flow_durations, (time_block_end - time_block_start + 1)::Int64)
                end
            end

            # Step 1.2. Loop over each constraint
            for (cons_idx, time_block_start, time_block_end) in zip(
                group_row.cons_idx::Vector{Union{Missing,Int64}},
                group_row.cons_time_block_start::Vector{Union{Missing,Int32}},
                group_row.cons_time_block_end::Vector{Union{Missing,Int32}},
            )
                time_block = time_block_start:time_block_end
                workspace_agg = Dict{Int,Float64}()
                # Step 1.2.1.
                for timestep in time_block
                    for (var_idx, var_coefficient) in workspace[timestep]
                        if !haskey(workspace_agg, var_idx)
                            # First time a variable is encountered it adds to the aggregation
                            workspace_agg[var_idx] = var_coefficient
                        elseif multiply_by_duration
                            # In this case, accumulates more of the variable,
                            # i.e., which effectively multiplies the variable
                            # by its duration in the time block
                            workspace_agg[var_idx] += var_coefficient
                        end
                    end
                end
                if length(workspace_agg) > 0
                    # Step 1.2.2.
                    cons.expressions[case.expr_key][cons_idx] = sum(
                        duration * flow.container[var_idx] for (var_idx, duration) in workspace_agg
                    )
                end
                if conditions_to_add_min_outgoing_flow_duration
                    cons.coefficients[:min_outgoing_flow_duration][cons_idx] =
                        outgoing_flow_durations
                end
            end
        end
    end

    return
end

"""
    add_expression_is_charging_terms_rep_period_constraints!(df_cons,
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
function add_expression_is_charging_terms_rep_period_constraints!(
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
    add_expression_units_on_terms_rep_period_constraints!(
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
function add_expression_units_on_terms_rep_period_constraints!(
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
    add_expression_terms_over_clustered_year_constraints!(df_inter,
                                               df_flows,
                                               df_map,
                                               graph,
                                               representative_periods,
                                               )

Computes the incoming and outgoing expressions per row of df_inter for the constraints
that are between (inter) the representative periods.

This function is only used internally in the model.

"""
function add_expression_terms_over_clustered_year_constraints!(
    cons::TulipaConstraint,
    flow::TulipaVariable,
    df_map, # TODO: Figure out how to handle this
    graph,
    representative_periods;
    is_storage_level = false,
)
    num_rows = size(cons.indices, 1)
    cons.expressions[:outgoing] = Vector{JuMP.AffExpr}(undef, num_rows)

    if is_storage_level
        cons.expressions[:incoming] = Vector{JuMP.AffExpr}(undef, num_rows)
        cons.expressions[:inflows_profile_aggregation] = Vector{JuMP.AffExpr}(undef, num_rows)
    end

    # TODO: The interaction between year and timeframe is not clear yet, so this is probably wrong
    #   At this moment, that relation is ignored (we don't even look at df_inter.year)

    # Incoming, outgoing flows, and profile aggregation
    for row_cons in eachrow(cons.indices)
        cons.expressions[:outgoing][row_cons.index] = JuMP.AffExpr(0.0)
        if is_storage_level
            cons.expressions[:incoming][row_cons.index] = JuMP.AffExpr(0.0)
            cons.expressions[:inflows_profile_aggregation][row_cons.index] = JuMP.AffExpr(0.0)
        end

        sub_df_map = DataFrames.subset(
            df_map,
            :period => p -> row_cons.period_block_start .<= p .<= row_cons.period_block_end,
            :weight => weight -> weight .> 0;
            view = true,
        )

        for row_map in eachrow(sub_df_map)
            # Skip inactive row_cons or undefined for that year
            # TODO: This is apparently never happening
            # if !get(graph[row_cons.asset].active, row_map.year, false)
            #     continue
            # end

            sub_df_flows = DataFrames.subset(
                flow.indices,
                :from => from -> from .== row_cons.asset,
                :year => year -> year .== row_map.year,
                :rep_period => rep_period -> rep_period .== row_map.rep_period;
                view = true,
            )

            duration = sub_df_flows.time_block_end .- sub_df_flows.time_block_start .+ 1
            if is_storage_level
                JuMP.add_to_expression!(
                    cons.expressions[:outgoing][row_cons.index],
                    row_map.weight,
                    LinearAlgebra.dot(
                        flow.container[sub_df_flows.index],
                        duration ./ sub_df_flows.efficiency,
                    ),
                )
            else
                JuMP.add_to_expression!(
                    cons.expressions[:outgoing][row_cons.index],
                    row_map.weight,
                    LinearAlgebra.dot(flow.container[sub_df_flows.index], duration),
                )
            end

            if is_storage_level
                # TODO: There is some repetition here or am I missing something?
                sub_df_flows = DataFrames.subset(
                    flow.indices,
                    :to => to -> to .== row_cons.asset,
                    :year => year -> year .== row_map.year,
                    :rep_period => rep_period -> rep_period .== row_map.rep_period;
                    view = true,
                )

                duration = sub_df_flows.time_block_end .- sub_df_flows.time_block_start .+ 1

                JuMP.add_to_expression!(
                    cons.expressions[:incoming][row_cons.index],
                    row_map.weight,
                    LinearAlgebra.dot(
                        flow.container[sub_df_flows.index],
                        duration .* sub_df_flows.efficiency,
                    ),
                )

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
    connection,
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
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_conversion],
        variables[:flow];
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_storage_rep_period],
        variables[:flow];
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_consumer],
        variables[:flow];
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_hub],
        variables[:flow];
        use_highest_resolution = true,
        multiply_by_duration = false,
    )

    for table_name in (
        :capacity_incoming,
        :capacity_incoming_non_investable_storage_with_binary,
        :capacity_incoming_investable_storage_with_binary,
        :capacity_outgoing,
        :capacity_outgoing_non_investable_storage_with_binary,
        :capacity_outgoing_investable_storage_with_binary,
    )
        @timeit to "add_expression_terms_rep_period_constraints! for $table_name" add_expression_terms_rep_period_constraints!(
            connection,
            constraints[table_name],
            variables[:flow];
            use_highest_resolution = true,
            multiply_by_duration = false,
        )

        @timeit to "add_expression_is_charging_terms_rep_period_constraints! for $table_name" add_expression_is_charging_terms_rep_period_constraints!(
            constraints[table_name],
            variables[:is_charging],
            expression_workspace,
        )
    end

    for table_name in (
        :ramping_without_unit_commitment,
        :ramping_with_unit_commitment,
        :max_ramp_with_unit_commitment,
        :max_ramp_without_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
    )
        @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
            connection,
            constraints[table_name],
            variables[:flow];
            use_highest_resolution = true,
            multiply_by_duration = false,
            add_min_outgoing_flow_duration = true,
        )
    end
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        constraints[:balance_storage_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods;
        is_storage_level = true,
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        constraints[:max_energy_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods,
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        constraints[:min_energy_over_clustered_year],
        variables[:flow],
        timeframe.map_periods_to_rp,
        graph,
        representative_periods,
    )
    @timeit to "add_expression_is_charging_terms_rep_period_constraints!" add_expression_is_charging_terms_rep_period_constraints!(
        constraints[:capacity_incoming],
        variables[:is_charging],
        expression_workspace,
    )
    for table_name in (
        :ramping_without_unit_commitment,
        :ramping_with_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
        :max_ramp_with_unit_commitment,
    )
        @timeit to "add_expression_units_on_terms_rep_period_constraints!" add_expression_units_on_terms_rep_period_constraints!(
            constraints[table_name],
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

function prepare_profiles_structure(connection)
    rep_period = Dict(
        (row.profile_name, row.year, row.rep_period) => [
            row.value for row in DuckDB.query(
                connection,
                "SELECT profile.value
                FROM profiles_rep_periods AS profile
                WHERE
                    profile.profile_name = '$(row.profile_name)'
                    AND profile.year = $(row.year)
                    AND profile.rep_period = $(row.rep_period)
                ",
            )
        ] for row in DuckDB.query(
            connection,
            "SELECT DISTINCT
                profiles.profile_name,
                profiles.year,
                profiles.rep_period
            FROM profiles_rep_periods AS profiles
            ",
        )
    )

    over_clustered_year = Dict(
        (row.profile_name, row.year) => [
            row.value for row in DuckDB.query(
                connection,
                "SELECT profile.value
                FROM profiles_timeframe AS profile
                WHERE
                    profile.profile_name = '$(row.profile_name)'
                    AND profile.year = $(row.year)
                ",
            )
        ] for row in DuckDB.query(
            connection,
            "SELECT DISTINCT
                profiles.profile_name,
                profiles.year
            FROM profiles_timeframe AS profiles
            ",
        )
    )

    return ProfileLookup(rep_period, over_clustered_year)
end
