# Auxiliary functions to create the model

function _check_if_table_exists(connection, table_name)
    existence_query = DBInterface.execute(
        connection,
        "SELECT table_name FROM information_schema.tables WHERE table_name = '$table_name'",
    )
    return length(collect(existence_query)) > 0
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
function profile_aggregation(agg, profiles, year, commission_year, key, block, default_value)
    if haskey(profiles, year) &&
       haskey(profiles[year], commission_year) &&
       haskey(profiles[year][commission_year], key)
        return agg(profiles[year][commission_year][key][block])
    else
        return agg(Iterators.repeated(default_value, length(block)))
    end
end

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
