# Auxiliary functions to create the model

"""
    is_active(graph, a, y)
    is_active(graph, (u, v), y)

Returns `graph[a].active[y][y]` or `graph[u, v].active[y][y]` or `false` if intermediary values are
missing.
"""
function is_active(graph, graph_key, y)
    active_dict = _get_graph_asset_or_flow(graph, graph_key).active # graph[...].active
    if !haskey(active_dict, y)
        return false
    else
        return get(active_dict[y], y, false)
    end
end

"""
    _get_graph_asset_or_flow(graph, a)
    _get_graph_asset_or_flow(graph, (u, v))

Returns `graph[a]` or `graph[u, v]`.
"""
_get_graph_asset_or_flow(graph, a) = graph[a]
_get_graph_asset_or_flow(graph, f::Tuple) = graph[f...]

"""
    get_graph_value_or_missing(graph, graph_key, field_key)
    get_graph_value_or_missing(graph, graph_key, field_key, year)

Get `graph[graph_key].field_key` (or `graph[graph_key].field_key[year]`) or return `missing` if
any of the values do not exist.
We also check if `graph[graph_key].active[year]` is true if the `year` is passed and return
`missing` otherwise.
"""
function get_graph_value_or_missing(graph, graph_key, field_key)
    g = _get_graph_asset_or_flow(graph, graph_key)
    return getproperty(g, field_key)
end
function get_graph_value_or_missing(graph, graph_key, field_key, year)
    if !is_active(graph, graph_key, year)
        return missing
    end
    g = get_graph_value_or_missing(graph, graph_key, field_key)
    return get(g, year, missing)
end

"""
    safe_comparison(graph, a, value, key)
    safe_comparison(graph, a, value, key, year)

Check if `graph[a].value` (or `graph[a].value[year]`) is equal to `value`.
This function assumes that if `graph[a].value` is a dictionary and `value` is not, then you made a mistake.
This makes it safer, because it will not silently return `false`.
It also checks for missing.
"""
function safe_comparison(graph, a, value1, args...)
    value2 = get_graph_value_or_missing(graph, a, args...)
    if ismissing(value1) || ismissing(value2)
        return false
    end
    return cmp(value1, value2) == 0 # Will error is one is a container (vector, dict) and the other is not
end

"""
    safe_inclusion(graph, a, value, key)
    safe_inclusion(graph, a, value, key, year)

Check if `graph[a].value` (or `graph[a].value[year]`) is in `values`.
This correctly check that `missing in [missing]` returns `false`.
"""
function safe_inclusion(graph, a, values::Vector, args...)
    value = get_graph_value_or_missing(graph, a, args...)
    return coalesce(value in values, false)
end

"""
    filter_graph(graph, elements, value, key)
    filter_graph(graph, elements, value, key, year)

Helper function to filter elements (assets or flows) in the graph given a key (and possibly year) and value (or values).
In the safest case, this is equivalent to the filters

```julia
filter_assets_whose_key_equal_to_value = a -> graph[a].key == value
filter_assets_whose_key_year_equal_to_value = a -> graph[a].key[year] in value
filter_flows_whose_key_equal_to_value = f -> graph[f...].key == value
filter_flows_whose_key_year_equal_to_value = f -> graph[f...].key[year] in value
```
"""
filter_graph(graph, elements, value, args...) =
    filter(e -> safe_comparison(graph, e, value, args...), elements)
filter_graph(graph, elements, values::Vector, args...) =
    filter(e -> safe_inclusion(graph, e, values, args...), elements)

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
