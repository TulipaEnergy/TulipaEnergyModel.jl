"""
    attach_expression_on_constraints_grouping_variables!(
        connection,
        constraint,
        variable,
        expr_name;
        agg_strategy
    )

Computes the intersection of the constraint and variable grouping by (:asset,
:year, :rep_period).

The intersection is made on time blocks, so both the constraint table and the
variable table must have columns index, time_block_start and time_block_end.

The variable `expr_name` will be the name of the attached expression.

The `agg_strategy` must be either `:sum`, `:mean`, and `:unique_sum`,
indicating how to aggregate the variables for a given constraint time block.

# Implementation

The expression uses a workspace to store all variables defined for each timestep.
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
- On step 1.2.1, the aggregation can be by either
    - :sum - add the coefficients
    - :mean - add the coefficients and divide by number of times the variable appears
    - :unique_sum - use 1.0 for the coefficient (this is not robust)
"""
function attach_expression_on_constraints_grouping_variables!(
    connection,
    cons::TulipaConstraint,
    var::TulipaVariable,
    expr_name,
    workspace;
    agg_strategy::Symbol,
)
    if !(agg_strategy in (:sum, :mean, :unique_sum))
        error("Argument $agg_strategy must be :sum, :mean, or :unique_sum")
    end

    grouped_cons_table_name = "t_grouped_$(cons.table_name)"
    _create_group_table_if_not_exist!(
        connection,
        cons.table_name,
        grouped_cons_table_name,
        [:asset, :year, :rep_period],
        [:index, :time_block_start, :time_block_end],
    )

    grouped_var_table_name = "t_grouped_$(var.table_name)"
    _create_group_table_if_not_exist!(
        connection,
        var.table_name,
        grouped_var_table_name,
        [:asset, :year, :rep_period],
        [:index, :time_block_start, :time_block_end],
    )

    num_rows = get_num_rows(connection, cons)
    attach_expression!(cons, expr_name, Vector{JuMP.AffExpr}(undef, num_rows))
    cons.expressions[expr_name] .= JuMP.AffExpr(0.0)

    # Loop over each group
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
        FROM $grouped_cons_table_name AS cons
        LEFT JOIN $grouped_var_table_name AS var
            ON cons.asset = var.asset
            AND cons.year = var.year
            AND cons.rep_period = var.rep_period
        WHERE
            len(var.index) > 0
        ",
    )
        empty!.(workspace)

        # Loop over each variable in the group
        for (var_idx::Int64, time_block_start::Int32, time_block_end::Int32) in zip(
            group_row.var_idx::Vector{Union{Missing,Int64}},
            group_row.var_time_block_start::Vector{Union{Missing,Int32}},
            group_row.var_time_block_end::Vector{Union{Missing,Int32}},
        )
            for timestep in time_block_start:time_block_end
                workspace[timestep][var_idx] = 1.0
            end
        end

        # Loop over each constraint
        for (cons_idx::Int64, time_block_start::Int32, time_block_end::Int32) in zip(
            group_row.cons_idx::Vector{Union{Missing,Int64}},
            group_row.cons_time_block_start::Vector{Union{Missing,Int32}},
            group_row.cons_time_block_end::Vector{Union{Missing,Int32}},
        )
            time_block = time_block_start:time_block_end

            # We keep the coefficient and count to compute the mean later
            workspace_coef_agg = Dict{Int,Float64}()
            workspace_count_agg = Dict{Int,Int}()

            for timestep in time_block
                for (var_idx, var_coefficient) in workspace[timestep]
                    if !haskey(workspace_coef_agg, var_idx)
                        # First time a variable is encountered it adds to the aggregation
                        workspace_coef_agg[var_idx] = var_coefficient
                        workspace_count_agg[var_idx] = 1
                    else
                        # For the other times, aggregate the coefficient and increase the counter
                        workspace_coef_agg[var_idx] += var_coefficient
                        workspace_count_agg[var_idx] += 1
                    end
                end
            end

            if length(workspace_coef_agg) > 0
                cons.expressions[expr_name][cons_idx] = JuMP.AffExpr(0.0)
                this_expr = cons.expressions[expr_name][cons_idx]
                for (var_idx, coef) in workspace_coef_agg
                    count = workspace_count_agg[var_idx]

                    if agg_strategy == :sum
                        JuMP.add_to_expression!(this_expr, coef, var.container[var_idx])
                    elseif agg_strategy == :mean
                        JuMP.add_to_expression!(this_expr, coef / count, var.container[var_idx])
                    elseif agg_strategy == :unique_sum
                        JuMP.add_to_expression!(this_expr, 1.0, var.container[var_idx])
                    end
                end
            end
        end
    end

    return
end
