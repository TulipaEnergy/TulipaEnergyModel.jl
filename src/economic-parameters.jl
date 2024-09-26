export calculate_annualized_cost

"""
    calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

Calculates the annualized cost for each asset, both energy assets and transport assets, in each year using provided discount rates, economic lifetimes, and investment costs.

# Arguments
- `discount_rate::Dict`: A dictionary where the key is a tuple `(year, asset)` representing year and asset, and the value is the discount rate for that specific `(year, asset)` pair.
- `economic_lifetime::Dict`: A dictionary where the key is a tuple `(year, asset)` representing year and asset, and the value is the economic lifetime for that specific `(year, asset)` pair.
- `investment_cost::Dict`: A dictionary where the key is a tuple `(year, asset)` representing year and asset, and the value is the investment cost for that specific `(year, asset)` pair.
- `years::Array`: An array of years to be considered.
- `investable_assets::Dict`: A dictionary where the key is a year, and the value is an array of assets that are relevant for that year.

# Returns
- A `Dict` where the keys are tuples `(year, asset)` representing the year and the asset, and the values are the calculated annualized cost for each asset in each year.

# Formula
The annualized cost for each asset in year is calculated using the formula:

    annualized_cost = discount_rate[(year, asset)] / (
        (1 + discount_rate[(year, asset)]) *
        (1 - 1 / (1 + discount_rate[(year, asset)])^economic_lifetime[(year, asset)])
    ) * investment_cost[(year, asset)]

# Example for energy assets

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

# Example for transport assets

```jldoctest
discount_rate = Dict((2021, ("asset1","asset1")) => 0.05, (2021, ("asset2","asset1")) => 0.07,
                     (2022, ("asset1","asset1")) => 0.06, (2022, ("asset2","asset1")) => 0.08)

economic_lifetime = Dict((2021, ("asset1", "asset1")) => 10, (2021, ("asset2", "asset1")) => 15,
                         (2022, ("asset1", "asset1")) => 12, (2022, ("asset2", "asset1")) => 20)

investment_cost   = Dict((2021, ("asset1","asset1")) => 1000, (2021, ("asset2","asset1")) => 1500,
                         (2022, ("asset1","asset1")) => 1100, (2022, ("asset2","asset1")) => 1600)
years = [2021, 2022]

investable_assets = Dict(2021 => [("asset1","asset1"), ("asset2","asset1")],
                         2022 => [("asset1","asset1"), ("asset2","asset1")])

costs = calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

# output

Dict{Tuple{Int64, Tuple{String, String}}, Float64} with 4 entries:
  (2022, ("asset2", "asset1")) => 150.892
  (2021, ("asset1", "asset1")) => 123.338
  (2021, ("asset2", "asset1")) => 153.918
  (2022, ("asset1", "asset1")) => 123.778
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
        (year, asset) =>
            discount_rate[(year, asset)] / (
                (1 + discount_rate[(year, asset)]) *
                (1 - 1 / (1 + discount_rate[(year, asset)])^economic_lifetime[(year, asset)])
            ) * investment_cost[(year, asset)] for year in years for
        asset in investable_assets[year]
    )
    return annualized_cost
end
