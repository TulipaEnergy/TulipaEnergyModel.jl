# Auxiliary functions to create the model

"""
    _check_if_table_exists(connection, table_name)

Check if table `table_name` exists in the connection.
"""
function _check_if_table_exists(connection, table_name)
    existence_query = DBInterface.execute(
        connection,
        "SELECT table_name FROM information_schema.tables WHERE table_name = '$table_name'",
    )
    return length(collect(existence_query)) > 0
end

"""
    _profile_aggregate(profiles, tuple_key, time_block, agg_functions, default_value)

Aggregates the `profiles[tuple_key]` over the `time_block` using the `agg_function` function.
If the profile does not exist, uses `default_value` instead of **each** profile value.

`profiles` should be a dictionary of profiles, and `tuple_key` should be either
`(profile_name, year, rep_period)` for the profiles of representative periods
or `(profile_name, year)` for the profiles over clustered years.

If `profiles[tuple_key]` exists, then this function computes the aggregation of `V = profiles[tuple_key]`
over the range `time_block` using the aggregator `agg_function`, i.e., `agg_function(V[time_block])`.
If it does not exist, then `V[time_block]` is substituted by a vector of the corresponding size and `default_value`.
"""
function _profile_aggregate(profiles, tuple_key::Tuple, time_block, agg_function, default_value)
    if any(ismissing, tuple_key) || !haskey(profiles, tuple_key)
        return agg_function(Iterators.repeated(default_value, length(time_block)))
    end
    profile_value = profiles[tuple_key]
    return agg_function(skipmissing(profile_value[time_block]))
end

"""
    _create_group_table_if_not_exist!(
        connection,
        table_name,
        grouped_table_name,
        group_by_columns,
        array_agg_columns;
        rename_columns = Dict(),
        order_agg_by = "index",
    )

Create a grouped table grouping the `table_name` into the `grouped_table_name`.
The `group_by_columns` are the columns that are used in the group by (e.g., asset, year, rep_period),
and the `array_agg_columns` are the columns that are aggregated into arrays (e.g., index, time_block_start, time_block_end).

It is expected that the original table has an `index` column, which is used in the ordering of the `array_agg_columns`.
Otherwise, please pass the argument `order_agg_by` with the column that should be used for this ordering.

If one of the columns has to be renamed, use the `rename_columns` dictionary.
"""
function _create_group_table_if_not_exist!(
    connection,
    table_name,
    grouped_table_name,
    group_by_columns,
    array_agg_columns;
    rename_columns = Dict(),
    order_agg_by = :index,
)
    if _check_if_table_exists(connection, grouped_table_name)
        return
    elseif length(group_by_columns) == 0
        error("`group_by_columns` cannot be empty")
    elseif length(array_agg_columns) == 0
        error("`array_agg_columns` cannot be empty")
    end

    select_string = join(
        (
            "t.$col" * (haskey(rename_columns, col) ? " AS $(rename_columns[col])" : "") for
            col in group_by_columns
        ),
        ", ",
    )
    group_by_string = join(("t.$col" for col in group_by_columns), ", ")
    array_agg_string = join(
        ("ARRAY_AGG(t.$col ORDER BY $order_agg_by) AS $col" for col in array_agg_columns),
        ", ",
    )

    sql_query = "CREATE TEMP TABLE $grouped_table_name AS
        SELECT $select_string, $array_agg_string,
        FROM $table_name AS t
        GROUP BY $group_by_string"

    DuckDB.query(connection, sql_query)

    return
end
