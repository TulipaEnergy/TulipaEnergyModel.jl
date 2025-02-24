# Tools to prepare data and structures to the model creation
export prepare_profiles_structure

"""
    add_expression_terms_rep_period_constraints!(
        connection,
        cons,
        flow;
        use_highest_resolution = true,
        multiply_by_duration = true,
        add_min_outgoing_flow_duration = false,
    )

Computes the incoming and outgoing expressions per row of `cons` for the constraints
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
    flow::TulipaVariable,
    workspace;
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
    num_rows = get_num_rows(connection, cons)

    # The SQL strategy to improve looping over the groups and then the
    # constraints and variables, is to create grouped tables beforehand and join them
    # The grouped constraint table is created below
    grouped_cons_table_name = "t_grouped_$(cons.table_name)"
    _create_group_table_if_not_exist!(
        connection,
        cons.table_name,
        grouped_cons_table_name,
        [:asset, :year, :rep_period],
        [:index, :time_block_start, :time_block_end],
    )

    for case in cases
        attach_expression!(cons, case.expr_key, Vector{JuMP.AffExpr}(undef, num_rows))
        cons.expressions[case.expr_key] .= JuMP.AffExpr(0.0)
        conditions_to_add_min_outgoing_flow_duration =
            add_min_outgoing_flow_duration && case.expr_key == :outgoing
        if conditions_to_add_min_outgoing_flow_duration
            attach_coefficient!(cons, :min_outgoing_flow_duration, ones(num_rows))
        end

        # The grouped variable table is created below for each case (from=asset, to=asset)
        grouped_var_table_name = "t_grouped_$(flow.table_name)_match_on_$(case.asset_match)"
        _create_group_table_if_not_exist!(
            connection,
            flow.table_name,
            grouped_var_table_name,
            [case.asset_match, :year, :rep_period],
            [:index, :time_block_start, :time_block_end, :efficiency];
            rename_columns = Dict(case.asset_match => :asset),
        )

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
                    cons.expressions[case.expr_key][cons_idx] = JuMP.AffExpr(0.0)
                    this_expr = cons.expressions[case.expr_key][cons_idx]
                    for (var_idx, duration) in workspace_agg
                        JuMP.add_to_expression!(this_expr, duration, flow.container[var_idx])
                    end
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
    add_expression_terms_over_clustered_year_constraints!(
        connection,
        cons,
        flow,
        profiles;
        is_storage_level = false,
    )

Computes the incoming and outgoing expressions per row of df_inter for the constraints
that are between (inter) the representative periods.

This function is only used internally in the model.

"""
function add_expression_terms_over_clustered_year_constraints!(
    connection,
    cons::TulipaConstraint,
    flow::TulipaVariable,
    workspace;
    is_storage_level = false,
)
    num_rows = get_num_rows(connection, cons)

    cases = [(expr_key = :outgoing, asset_match = :from)]
    if is_storage_level
        push!(cases, (expr_key = :incoming, asset_match = :to))
        attach_coefficient!(cons, :inflows_profile_aggregation, zeros(num_rows))
    end

    for case in cases
        attach_expression!(cons, case.expr_key, Vector{JuMP.AffExpr}(undef, num_rows))
        cons.expressions[case.expr_key] .= JuMP.AffExpr(0.0)
    end

    grouped_cons_table_name = "t_grouped_$(cons.table_name)"
    _create_group_table_if_not_exist!(
        connection,
        cons.table_name,
        grouped_cons_table_name,
        [:asset, :year],
        [:index, :period_block_start, :period_block_end],
    )

    grouped_rpmap_over_rp_table_name = "t_grouped_rpmap_over_rp"
    _create_group_table_if_not_exist!(
        connection,
        "rep_periods_mapping",
        grouped_rpmap_over_rp_table_name,
        [:year, :rep_period],
        [:period, :weight];
        order_agg_by = :period,
    )

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
                ARRAY_AGG(COALESCE(rpmap.period, []) ORDER BY var.rep_period) AS var_periods,
                ARRAY_AGG(COALESCE(rpmap.weight, []) ORDER BY var.rep_period) AS var_weights,
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
            empty!.(workspace)

            for (
                var_indices,
                var_time_block_start_vec,
                var_time_block_end_vec,
                var_efficiencies,
                var_periods,
                var_weights,
            ) in zip(
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
                        if !haskey(workspace[period], var_idx)
                            workspace[period][var_idx] = 0.0
                        end
                        workspace[period][var_idx] += var_coef * weight
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
                    mergewith!(+, workspace_aggregation, workspace[period])
                end

                if length(workspace_aggregation) > 0
                    cons.expressions[case.expr_key][cons_idx] = JuMP.AffExpr(0.0)
                    this_expr = cons.expressions[case.expr_key][cons_idx]
                    for (var_idx, coefficient) in workspace_aggregation
                        JuMP.add_to_expression!(this_expr, coefficient, flow.container[var_idx])
                    end
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

function add_expressions_to_constraints!(connection, variables, constraints)
    # creating a workspace with enough entries for any of the representative periods or normal periods
    maximum_num_timesteps = only(
        row[1] for
        row in DuckDB.query(connection, "SELECT MAX(num_timesteps) FROM rep_periods_data")
    )::Int32
    maximum_num_periods = only(
        row[1] for row in DuckDB.query(connection, "SELECT MAX(period) FROM rep_periods_mapping")
    )::Int32
    Tmax = max(maximum_num_timesteps, maximum_num_periods)
    workspace = [Dict{Int,Float64}() for _ in 1:Tmax]

    # Unpack variables
    # Creating the incoming and outgoing flow expressions
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_conversion],
        variables[:flow],
        workspace;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_storage_rep_period],
        variables[:flow],
        workspace;
        use_highest_resolution = false,
        multiply_by_duration = true,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_consumer],
        variables[:flow],
        workspace;
        use_highest_resolution = true,
        multiply_by_duration = false,
    )
    @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
        connection,
        constraints[:balance_hub],
        variables[:flow],
        workspace;
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
            variables[:flow],
            workspace;
            use_highest_resolution = true,
            multiply_by_duration = false,
        )

        @timeit to "attach is_charging expression to $table_name" attach_expression_on_constraints_grouping_variables!(
            connection,
            constraints[table_name],
            variables[:is_charging],
            :is_charging,
            workspace,
            agg_strategy = :mean,
        )
    end

    for table_name in (
        :min_output_flow_with_unit_commitment,
        :max_ramp_with_unit_commitment,
        :max_ramp_without_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
    )
        @timeit to "add_expression_terms_rep_period_constraints!" add_expression_terms_rep_period_constraints!(
            connection,
            constraints[table_name],
            variables[:flow],
            workspace;
            use_highest_resolution = true,
            multiply_by_duration = false,
            add_min_outgoing_flow_duration = true,
        )
    end
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        connection,
        constraints[:balance_storage_over_clustered_year],
        variables[:flow],
        workspace;
        is_storage_level = true,
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        connection,
        constraints[:max_energy_over_clustered_year],
        variables[:flow],
        workspace;
    )
    @timeit to "add_expression_terms_over_clustered_year_constraints!" add_expression_terms_over_clustered_year_constraints!(
        connection,
        constraints[:min_energy_over_clustered_year],
        variables[:flow],
        workspace;
    )
    for table_name in (
        :min_output_flow_with_unit_commitment,
        :max_output_flow_with_basic_unit_commitment,
        :max_ramp_with_unit_commitment,
    )
        @timeit to "attach units_on expression to $table_name" attach_expression_on_constraints_grouping_variables!(
            connection,
            constraints[table_name],
            variables[:units_on],
            :units_on,
            workspace,
            agg_strategy = :unique_sum,
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
