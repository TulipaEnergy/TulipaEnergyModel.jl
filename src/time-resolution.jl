export compute_rp_partition, compute_constraints_partitions

using SparseArrays

"""
    cons_partitions = compute_constraints_partitions(graph, representative_periods)

Computes the constraints partitions using the assets and flows partitions stored in the graph,
and the representative periods.

The function computes the constraints partitions by iterating over the partition dictionary,
which specifies the partition strategy for each resolution (i.e., lowest or highest).
For each asset and representative period, it calls the `compute_rp_partition` function
to compute the partition based on the strategy.
"""
function compute_constraints_partitions(graph, representative_periods)
    constraints_partitions = Dict{Symbol,Dict{Tuple{String,Int},Vector{TimeBlock}}}()

    _inflows(a, rp) = [graph[u, a].rep_periods_partitions[rp] for u in inneighbor_labels(graph, a)]
    _outflows(a, rp) =
        [graph[a, v].rep_periods_partitions[rp] for v in outneighbor_labels(graph, a)]
    _allflows(a, rp) = [_inflows(a, rp); _outflows(a, rp)]
    _assets(a, rp) = [graph[a].rep_periods_partitions[rp]]
    _all(a, rp) = [_allflows(a, rp); _assets(a, rp)]

    partitions_cases = [
        (
            name = :lowest,
            partitions = _allflows,
            strategy = :lowest,
            asset_filter = a -> graph[a].type in ["conversion", "producer"],
        ),
        (
            name = :lowest_storage_level_intra_rp,
            partitions = _all,
            strategy = :lowest,
            asset_filter = a -> graph[a].type == "storage" && !graph[a].is_seasonal,
        ),
        (
            name = :highest_in_out,
            partitions = _allflows,
            strategy = :highest,
            asset_filter = a -> graph[a].type in ["hub", "consumer"],
        ),
        (
            name = :highest_in,
            partitions = _inflows,
            strategy = :highest,
            asset_filter = a -> graph[a].type in ["storage"],
        ),
        (
            name = :highest_out,
            partitions = _outflows,
            strategy = :highest,
            asset_filter = a -> graph[a].type in ["producer", "storage", "conversion"],
        ),
    ]

    num_rep_periods = length(representative_periods)

    for (name, partitions, strategy, asset_filter) in partitions_cases
        constraints_partitions[name] = OrderedDict(
            (a, rp) => begin
                P = partitions(a, rp)
                if length(P) > 0
                    compute_rp_partition(partitions(a, rp), strategy)
                else
                    Vector{TimeBlock}[]
                end
            end for a in labels(graph), rp = 1:num_rep_periods if asset_filter(a)
        )
    end

    return constraints_partitions
end

"""
    rp_partition = compute_rp_partition(partitions, :lowest)

Given the time steps of various flows/assets in the `partitions` input, compute the representative period partitions.

Each element of `partitions` is a partition with the following assumptions:

  - An element is of the form `V = [r₁, r₂, …, rₘ]`, where each `rᵢ` is a range `a:b`.
  - `r₁` starts at 1.
  - `rᵢ₊₁` starts at the end of `rᵢ` plus 1.
  - `rₘ` ends at some value `N`, that is the same for all elements of `partitions`.

Notice that this implies that they form a disjunct partition of `1:N`.

The output will also be a partition with the conditions above.

## Strategies

### :lowest

If `strategy = :lowest` (default), then the output is constructed greedily,
i.e., it selects the next largest breakpoint following the algorithm below:

 0. Input: `Vᴵ₁, …, Vᴵₚ`, a list of time blocks. Each element of `Vᴵⱼ` is a range `r = r.start:r.end`. Output: `V`.
 1. Compute the end of the representative period `N` (all `Vᴵⱼ` should have the same end)
 2. Start with an empty `V = []`
 3. Define the beginning of the range `s = 1`
 4. Define an array with all the next breakpoints `B` such that `Bⱼ` is the first `r.end` such that `r.end ≥ s` for each `r ∈ Vᴵⱼ`.
 5. The end of the range will be the `e = max Bⱼ`.
 6. Define `r = s:e` and add `r` to the end of `V`.
 7. If `e = N`, then END
 8. Otherwise, define `s = e + 1` and go to step 4.

#### Examples

```jldoctest
partition1 = [1:4, 5:8, 9:12]
partition2 = [1:3, 4:6, 7:9, 10:12]
compute_rp_partition([partition1, partition2], :lowest)

# output

3-element Vector{UnitRange{Int64}}:
 1:4
 5:8
 9:12
```

```jldoctest
partition1 = [1:1, 2:3, 4:6, 7:10, 11:12]
partition2 = [1:2, 3:4, 5:5, 6:7, 8:9, 10:12]
compute_rp_partition([partition1, partition2], :lowest)

# output

5-element Vector{UnitRange{Int64}}:
 1:2
 3:4
 5:6
 7:10
 11:12
```

### :highest

If `strategy = :highest`, then the output selects includes all the breakpoints from the input.
Another way of describing it, is to select the minimum end-point instead of the maximum end-point in the `:lowest` strategy.

#### Examples

```jldoctest
partition1 = [1:4, 5:8, 9:12]
partition2 = [1:3, 4:6, 7:9, 10:12]
compute_rp_partition([partition1, partition2], :highest)

# output

6-element Vector{UnitRange{Int64}}:
 1:3
 4:4
 5:6
 7:8
 9:9
 10:12
```

```jldoctest
partition1 = [1:1, 2:3, 4:6, 7:10, 11:12]
partition2 = [1:2, 3:4, 5:5, 6:7, 8:9, 10:12]
compute_rp_partition([partition1, partition2], :highest)

# output

10-element Vector{UnitRange{Int64}}:
 1:1
 2:2
 3:3
 4:4
 5:5
 6:6
 7:7
 8:9
 10:10
 11:12
```
"""
function compute_rp_partition(
    partitions::AbstractVector{<:AbstractVector{<:UnitRange{<:Integer}}},
    strategy,
)
    valid_strategies = [:highest, :lowest]
    if !(strategy in valid_strategies)
        error("`strategy` should be one of $valid_strategies. See docs for more info.")
    end
    # Get Vᴵ₁, the last range of it, the last element of the range
    rp_end = partitions[1][end][end]
    for partition in partitions
        # Assumption: All start at 1 and end at N
        @assert partition[1][1] == 1
        @assert rp_end == partition[end][end]
    end
    rp_partition = UnitRange{Int}[] # List of ranges

    block_start = 1
    if strategy == :lowest
        while block_start ≤ rp_end
            # The next block end must be ≥ block start
            block_end = block_start
            for partition in partitions
                # For this partition, find the first block that ends after block_start
                for time_block in partition
                    tentative_end = time_block[end]
                    if tentative_end ≥ block_start
                        if tentative_end > block_end # Better block
                            block_end = tentative_end
                        end
                        break
                    end
                end
            end
            push!(rp_partition, block_start:block_end)
            block_start = block_end + 1
        end
    elseif strategy == :highest
        # We need all end points of each interval
        end_points_per_array = map(partitions) do x # For each partition
            last.(x) # Retrieve the last element of each interval
        end
        # Then we concatenate, remove duplicates, and sort.
        end_points = vcat(end_points_per_array...) |> unique |> sort
        for block_end in end_points
            push!(rp_partition, block_start:block_end)
            block_start = block_end + 1
        end
    end
    return rp_partition
end
