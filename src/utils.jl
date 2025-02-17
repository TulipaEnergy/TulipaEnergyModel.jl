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
    Δ = duration(block, rp, representative_periods)

Computes the duration of the `block` and multiply by the resolution of the
representative period `rp`.
"""
function duration(timesteps_block, rp, representative_periods)
    return length(timesteps_block) * representative_periods[rp].resolution
end
