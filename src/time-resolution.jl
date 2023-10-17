export resolution_matrix, compute_rp_periods

"""
    M = resolution_matrix(rp_periods, time_steps)

Computes the resolution balance matrix using the array of `rp_periods` and the array of `time_steps`.
The elements in these arrays must be ranges.

## Examples

The following two examples are for two flows/assets with resolutions of 3h and 4h, so that the representative period has 4h periods.

```jldoctest
rp_periods = [1:4, 5:8, 9:12]
time_steps = [1:4, 5:8, 9:12]
resolution_matrix(rp_periods, time_steps)

# output

3×3 Matrix{Float64}:
 1.0  0.0  0.0
 0.0  1.0  0.0
 0.0  0.0  1.0
```

```jldoctest
rp_periods = [1:4, 5:8, 9:12]
time_steps = [1:3, 4:6, 7:9, 10:12]
resolution_matrix(rp_periods, time_steps)

# output

3×4 Matrix{Float64}:
 1.0  0.333333  0.0       0.0
 0.0  0.666667  0.666667  0.0
 0.0  0.0       0.333333  1.0
```
"""
function resolution_matrix(
    rp_periods::AbstractVector{<:UnitRange{<:Integer}},
    time_steps::AbstractVector{<:UnitRange{<:Integer}},
)
    M = [
        length(period ∩ time_step) / length(time_step) for period in rp_periods,
        time_step in time_steps
    ]

    return M
end

"""
    rp_periods = compute_rp_periods(array_time_steps)

Given the time steps of various flows/assets in the `array_time_steps` input, compute the representative period splits.
Each element of `array_time_steps` is a an array of ranges.

## Examples

```jldoctest
time_steps1 = [1:4, 5:8, 9:12]
time_steps2 = [1:3, 4:6, 7:9, 10:12]
compute_rp_periods([time_steps1, time_steps2])

# output

3-element Vector{UnitRange{Int64}}:
 1:4
 5:8
 9:12
```
"""
function compute_rp_periods(
    array_time_steps::AbstractVector{<:AbstractVector{<:UnitRange{<:Integer}}},
)
    rp_periods = UnitRange{Int}[]
    period_start = 1
    representative_period_end = maximum(last.(last.(array_time_steps)))
    while period_start < representative_period_end
        period_end =
            maximum(last(T[findfirst(last.(T) .≥ period_start)]) for T in array_time_steps)
        @assert period_end ≥ period_start
        push!(rp_periods, period_start:period_end)
        period_start = period_end + 1
    end
    return rp_periods
end
