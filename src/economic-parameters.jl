export calculate_annualized_cost

"""
    calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

Calculates the annualized cost for each asset `a` in each year `y` using provided discount rates, economic lifetimes, and investment costs.

# Arguments
- `discount_rate::Dict`: A dictionary where the key is a tuple `(y, a)` representing year `y` and asset `a`, and the value is the discount rate for that specific `(y, a)` pair.
- `economic_lifetime::Dict`: A dictionary where the key is a tuple `(y, a)` representing year `y` and asset `a`, and the value is the economic lifetime for that specific `(y, a)` pair.
- `investment_cost::Dict`: A dictionary where the key is a tuple `(y, a)` representing year `y` and asset `a`, and the value is the investment cost for that specific `(y, a)` pair.
- `years::Array`: An array of years to be considered.
- `investable_assets::Dict`: A dictionary where the key is a year `y`, and the value is an array of assets `a` that are relevant for that year.

# Returns
- A `Dict` where the keys are tuples `(y, a)` representing the year `y` and the asset `a`, and the values are the calculated annualized cost for each asset in each year.

# Formula
The annualized cost for each asset `a` in year `y` is calculated using the formula:

    annualized_cost = discount_rate[(y, a)] / (
        (1 + discount_rate[(y, a)]) *
        (1 - 1 / (1 + discount_rate[(y, a)])^economic_lifetime[(y, a)])
    ) * investment_cost[(y, a)]

# Example

```jldoctest
discount_rate = Dict((2021, "asset1") => 0.05, (2021, "asset2") => 0.07,
                     (2022, "asset1") => 0.06, (2022, "asset2") => 0.08)

economic_lifetime = Dict((2021, "asset1") => 10, (2021, "asset2") => 15,
                         (2022, "asset1") => 12, (2022, "asset2") => 20)

investment_cost   = Dict((2021, "asset1") => 1000, (2021, "asset2") => 1500,
                         (2022, "asset1") => 1100, (2022, "asset2") => 1600)
years = [2021, 2022]

investable_assets = Dict(2021 => ["asset1", "asset2"],
                         2022 => ["asset1", "asset2"])

costs = calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

# output

Dict{Tuple{Int64, String}, Float64} with 4 entries:
  (2022, "asset2") => 150.892
  (2021, "asset1") => 123.338
  (2021, "asset2") => 153.918
  (2022, "asset1") => 123.778
```
"""
function calculate_annualized_cost(
    discount_rate,
    economic_lifetime,
    investment_cost,
    years,
    investable_assets,
)
    annualized_cost = Dict(
        (y, a) =>
            discount_rate[(y, a)] / (
                (1 + discount_rate[(y, a)]) *
                (1 - 1 / (1 + discount_rate[(y, a)])^economic_lifetime[(y, a)])
            ) * investment_cost[(y, a)] for y in years for a in investable_assets[y]
    )
    return annualized_cost
end
