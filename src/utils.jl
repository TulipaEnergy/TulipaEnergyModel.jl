# Auxiliary functions to create the model

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
