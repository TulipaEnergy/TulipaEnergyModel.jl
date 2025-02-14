# Tools to prepare data and structures to the model creation
export prepare_profiles_structure

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
    connection,
    cons::TulipaConstraint,
    flow::TulipaVariable,
    profiles;
    is_storage_level = false,
)
    num_rows = size(cons.indices, 1)

    cases = [(expr_key = :outgoing, asset_match = :from)]
    if is_storage_level
        push!(cases, (expr_key = :incoming, asset_match = :to))
        attach_coefficient!(cons, :inflows_profile_aggregation, zeros(num_rows))
    end

    for case in cases
        attach_expression!(cons, case.expr_key, Vector{JuMP.AffExpr}(undef, num_rows))
        cons.expressions[case.expr_key] .= JuMP.AffExpr(0.0)
    end

    # TODO: The interaction between year and timeframe is not clear yet, so this is probably wrong
    #   At this moment, that relation is ignored (we don't even look at df_inter.year)
    grouped_cons_table_name = "t_grouped_$(cons.table_name)"
    if !_check_if_table_exists(connection, grouped_cons_table_name)
        DuckDB.query(
            connection,
            "CREATE TEMP TABLE $grouped_cons_table_name AS
            SELECT
                cons.asset,
                cons.year,
                ARRAY_AGG(cons.index ORDER BY cons.index) AS index,
                ARRAY_AGG(cons.period_block_start ORDER BY cons.index) AS period_block_start,
                ARRAY_AGG(cons.period_block_end ORDER BY cons.index) AS period_block_end,
            FROM $(cons.table_name) AS cons
            GROUP BY cons.asset, cons.year
            ",
        )
    end

    grouped_rpmap_over_rp_table_name = "t_grouped_rpmap_over_rp"
    if !_check_if_table_exists(connection, grouped_rpmap_over_rp_table_name)
        DuckDB.query(
            connection,
            "CREATE TEMP TABLE $grouped_rpmap_over_rp_table_name AS
            SELECT
                rpmap.year,
                rpmap.rep_period,
                ARRAY_AGG(rpmap.period ORDER BY period) AS periods,
                ARRAY_AGG(rpmap.weight ORDER BY period) AS weights,
            FROM rep_periods_mapping AS rpmap
            GROUP BY rpmap.year, rpmap.rep_period
            ",
        )
    end

    # The flow_per_period_workspace holds the list of flows that will be aggregated in a given period
    maximum_num_periods = only(
        row[1] for row in DuckDB.query(connection, "SELECT MAX(period) FROM rep_periods_mapping")
    )::Int32
    flows_per_period_workspace = [Dict{Int,Float64}() for _ in 1:maximum_num_periods]

    for case in cases
        from_or_to = case.asset_match

        grouped_var_table_name = "t_grouped_$(flow.table_name)_match_on_$(from_or_to)"
        if !_check_if_table_exists(connection, grouped_var_table_name)
            error(
                """The table '$grouped_var_table_name' doesn't exist in the connection.
                This table is created in the 'add_expression_terms_rep_period_constraints!' function.
                Please, check if the function is being called before this one.""",
            )
        end

        for group_row in DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP TABLE t_groups AS
            SELECT
                cons.asset,
                cons.year,
                ANY_VALUE(cons.index) AS cons_indices,
                ANY_VALUE(cons.period_block_start) AS cons_period_block_start_vec,
                ANY_VALUE(cons.period_block_end) AS cons_period_block_end_vec,
                ARRAY_AGG(COALESCE(var.index, []) ORDER BY var.rep_period) AS var_indices,
                ARRAY_AGG(COALESCE(var.time_block_start, []) ORDER BY var.rep_period) AS var_time_block_start_vec,
                ARRAY_AGG(COALESCE(var.time_block_end, []) ORDER BY var.rep_period) AS var_time_block_end_vec,
                ARRAY_AGG(COALESCE(var.efficiency, []) ORDER BY var.rep_period) AS var_efficiencies,
                ARRAY_AGG(var.rep_period ORDER BY var.rep_period) AS var_rep_periods,
                ARRAY_AGG(rpdata.num_timesteps ORDER BY var.rep_period) AS num_timesteps,
                ARRAY_AGG(asset_milestone.storage_inflows ORDER BY var.rep_period) AS storage_inflows,
                ARRAY_AGG(COALESCE(rpmap.periods, []) ORDER BY var.rep_period) AS var_periods,
                ARRAY_AGG(COALESCE(rpmap.weights, []) ORDER BY var.rep_period) AS var_weights,
            FROM $grouped_cons_table_name AS cons
            LEFT JOIN $grouped_var_table_name AS var
                ON cons.asset = var.asset
                AND cons.year = var.year
            LEFT JOIN $grouped_rpmap_over_rp_table_name AS rpmap
                ON rpmap.year = cons.year
                AND rpmap.rep_period = var.rep_period
            LEFT JOIN rep_periods_data AS rpdata
                ON rpdata.year = cons.year
                AND rpdata.rep_period = var.rep_period
            LEFT JOIN asset_milestone
                ON asset_milestone.asset = cons.asset
                AND asset_milestone.milestone_year = cons.year
            GROUP BY cons.asset, cons.year;
            FROM t_groups
            ",
        )
            empty!.(flows_per_period_workspace)

            for (
                rp,
                storage_inflow,
                num_timesteps,
                var_indices,
                var_time_block_start_vec,
                var_time_block_end_vec,
                var_efficiencies,
                var_periods,
                var_weights,
            ) in zip(
                group_row.var_rep_periods,
                group_row.storage_inflows,
                group_row.num_timesteps,
                group_row.var_indices,
                group_row.var_time_block_start_vec,
                group_row.var_time_block_end_vec,
                group_row.var_efficiencies,
                group_row.var_periods,
                group_row.var_weights,
            )

                # Loop over each variable in the (group,rp) and accumulate them
                group_flows_accumulation = Dict{Int,Float64}()

                for (var_idx, time_block_start, time_block_end, var_efficiency) in zip(
                    var_indices,
                    var_time_block_start_vec,
                    var_time_block_end_vec,
                    var_efficiencies,
                )
                    coefficient = (time_block_end - time_block_start + 1)
                    if is_storage_level
                        if case.expr_key == :outgoing
                            coefficient /= var_efficiency
                        else
                            coefficient *= var_efficiency
                        end
                    end
                    group_flows_accumulation[var_idx] = coefficient
                end

                # Loop over each period in the group and add the accumulated flows to the workspace
                for (period, weight) in zip(var_periods, var_weights)
                    if weight == 0
                        continue
                    end
                    # Note to future. Using `mergewith!` did not work because the
                    # `combine` function is only applied for clashing entries, i.e., the weight is not applied uniformly to all entries.
                    # It passed for most cases, since `weight = 1` in most cases.
                    for (var_idx, var_coef) in group_flows_accumulation
                        if !haskey(flows_per_period_workspace[period], var_idx)
                            flows_per_period_workspace[period][var_idx] = 0.0
                        end
                        flows_per_period_workspace[period][var_idx] += var_coef * weight
                    end
                end
            end

            # Loop over each constraint and aggregate from the workspace into the expression
            for (cons_idx, period_block_start, period_block_end) in zip(
                group_row.cons_indices,
                group_row.cons_period_block_start_vec,
                group_row.cons_period_block_end_vec,
            )
                period_block = period_block_start:period_block_end
                workspace_aggregation = Dict{Int,Float64}()
                for period in period_block
                    mergewith!(+, workspace_aggregation, flows_per_period_workspace[period])
                end

                if length(workspace_aggregation) > 0
                    cons.expressions[case.expr_key][cons_idx] = sum(
                        coefficient * flow.container[var_idx] for
                        (var_idx, coefficient) in workspace_aggregation
                    )
                end
            end
        end
    end

    # Completely separate calculation for inflows_profile_aggregation
    if is_storage_level
        cons.coefficients[:inflows_profile_aggregation] .= [
            row.inflows_agg for row in DuckDB.query(
                connection,
                "
                SELECT
                    cons.index,
                    ANY_VALUE(cons.asset) AS asset,
                    ANY_VALUE(cons.year) AS year,
                    SUM(COALESCE(other.inflows_agg, 0.0)) AS inflows_agg,
                FROM cons_balance_storage_over_clustered_year AS cons
                LEFT JOIN (
                    SELECT
                        assets_profiles.asset AS asset,
                        assets_profiles.commission_year AS year,
                        rpmap.period AS period,
                        SUM(COALESCE(profiles.value, 0.0) * rpmap.weight * asset_milestone.storage_inflows) AS inflows_agg,
                    FROM assets_profiles
                    LEFT OUTER JOIN profiles_rep_periods AS profiles
                        ON assets_profiles.profile_name=profiles.profile_name
                        AND assets_profiles.profile_type='inflows'
                    LEFT JOIN rep_periods_mapping AS rpmap
                        ON rpmap.year = assets_profiles.commission_year
                        AND rpmap.year = profiles.year -- because milestone_year = commission_year
                        AND rpmap.rep_period = profiles.rep_period
                    LEFT JOIN asset_milestone
                        ON asset_milestone.asset = assets_profiles.asset
                        AND asset_milestone.milestone_year = assets_profiles.commission_year
                    GROUP BY
                        assets_profiles.asset,
                        assets_profiles.commission_year,
                        rpmap.period
                    ) AS other
                    ON cons.asset = other.asset
                    AND cons.year = other.year
                    AND cons.period_block_start <= other.period
                    AND cons.period_block_end >= other.period
                GROUP BY cons.index
                ORDER BY cons.index
                ",
            )
        ]
    end

    return
end

function add_expressions_to_constraints!(
    connection,
    variables,
    constraints,
    model,
    expression_workspace,
    profiles,
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
        connection,
        constraints[:balance_storage_over_clustered_year],
        variables[:flow],
        profiles,
        is_storage_level = true,
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        connection,
        constraints[:max_energy_over_clustered_year],
        variables[:flow],
        profiles,
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        connection,
        constraints[:min_energy_over_clustered_year],
        variables[:flow],
        profiles,
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
