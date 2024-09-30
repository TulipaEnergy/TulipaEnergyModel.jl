export calculate_annualized_cost

"""
    calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

Calculates the annualized cost for each asset, both energy assets and transport assets, in each year using provided discount rates, economic lifetimes, and investment costs.

# Arguments
- `discount_rate::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the discount rate.
- `economic_lifetime::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the economic lifetime.
- `investment_cost::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the investment cost.
- `years::Array`: An array of years to be considered.
- `investable_assets::Dict`: A dictionary where the key is a year, and the value is an array of assets that are relevant for that year.

# Returns
- A `Dict` where the keys are tuples `(year, asset)` representing the year and the asset, and the values are the calculated annualized cost for each asset in each year.

# Formula
The annualized cost for each asset in year is calculated using the formula:

    annualized_cost = discount_rate[asset] / (
        (1 + discount_rate[asset]) *
        (1 - 1 / (1 + discount_rate[asset])^economic_lifetime[asset])
    ) * investment_cost[(year, asset)]

# Example for energy assets

```jldoctest
discount_rate = Dict("asset1" => 0.05, "asset2" => 0.07)

economic_lifetime = Dict("asset1" => 10, "asset2" => 15)

investment_cost   = Dict((2021, "asset1") => 1000, (2021, "asset2") => 1500,
                         (2022, "asset1") => 1100, (2022, "asset2") => 1600)
years = [2021, 2022]

investable_assets = Dict(2021 => ["asset1", "asset2"],
                         2022 => ["asset1"])

costs = calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

# output

Dict{Tuple{Int64, String}, Float64} with 3 entries:
  (2021, "asset1") => 123.338
  (2021, "asset2") => 153.918
  (2022, "asset1") => 135.671
```

# Example for transport assets

```jldoctest
discount_rate = Dict(("asset1","asset2") => 0.05, ("asset3","asset4") => 0.07)

economic_lifetime = Dict(("asset1", "asset2") => 10, ("asset3", "asset4") => 15)

investment_cost   = Dict((2021, ("asset1","asset2")) => 1000, (2021, ("asset3","asset4")) => 1500,
                         (2022, ("asset1","asset2")) => 1100, (2022, ("asset3","asset4")) => 1600)
years = [2021, 2022]

investable_assets = Dict(2021 => [("asset1","asset2"), ("asset3","asset4")],
                         2022 => [("asset1","asset2")])

costs = calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

# output

Dict{Tuple{Int64, Tuple{String, String}}, Float64} with 3 entries:
  (2022, ("asset1", "asset2")) => 135.671
  (2021, ("asset3", "asset4")) => 153.918
  (2021, ("asset1", "asset2")) => 123.338
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
            discount_rate[asset] / (
                (1 + discount_rate[asset]) *
                (1 - 1 / (1 + discount_rate[asset])^economic_lifetime[asset])
            ) * investment_cost[(year, asset)] for year in years for
        asset in investable_assets[year]
    )
    return annualized_cost
end
