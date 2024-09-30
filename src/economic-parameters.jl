export calculate_annualized_cost, calculate_salvage_value, calculate_weight_for_investment_discounts

"""
    calculate_annualized_cost(discount_rate, economic_lifetime, investment_cost, years, investable_assets)

Calculates the annualized cost for each asset, both energy assets and transport assets, in each year using provided discount rates, economic lifetimes, and investment costs.

# Arguments
- `discount_rate::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the discount rate.
- `economic_lifetime::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the economic lifetime.
- `investment_cost::Dict`: A dictionary where the key is an tuple `(year, asset)` or `(year, (asset1, asset2))` for transport assets, and the value is the investment cost.
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

"""
    calculate_salvage_value(discount_rate,
                            economic_lifetime,
                            annualized_cost,
                            years,
                            investable_assets,
                            )

Calculates the salvage value for each asset, both energy assets and transport assets, in each year using provided AAA.

# Arguments
- `discount_rate::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the discount rate.
- `economic_lifetime::Dict`: A dictionary where the key is an `asset` or a pair of assets `(asset1, asset2)` for transport assets, and the value is the economic lifetime.
- `annualized_cost::Dict`: A `Dict` where the keys are tuples `(year, asset)` representing the year and the asset, and the values are the annualized cost for each asset in each year.
- `years::Array`: An array of years to be considered.
- `investable_assets::Dict`: A dictionary where the key is a year, and the value is an array of assets that are relevant for that year.

# Returns
- A `Dict` where the keys are tuples `(year, asset)` representing the year and the asset, and the values are the salvage value for each asset in each year.

# Formula
The salvage value for each asset in year is calculated using the formula:

salvage_value =
    annualized_cost[(year, asset)] * sum(
        1 / (1 + discount_rate[asset])^(year_alias - year) for
        year_alias in salvage_value_set[(year, asset)]
    )

# Example for energy assets

```jldoctest
discount_rate = Dict("asset1" => 0.05, "asset2" => 0.07)

economic_lifetime = Dict("asset1" => 10, "asset2" => 15)

annualized_cost =
    Dict((2021, "asset1") => 123.338, (2021, "asset2") => 153.918, (2022, "asset1") => 135.671)

years = [2021, 2022]

investable_assets = Dict(2021 => ["asset1", "asset2"], 2022 => ["asset1"])

salvage_value = calculate_salvage_value(
    discount_rate,
    economic_lifetime,
    annualized_cost,
    years,
    investable_assets,
)

# output
Dict{Tuple{Int64, String}, Float64} with 3 entries:
  (2021, "asset1") => 759.2
  (2021, "asset2") => 1202.24
  (2022, "asset1") => 964.325
```

# Example for transport assets

```jldoctest
discount_rate = Dict(("asset1", "asset2") => 0.05, ("asset3", "asset4") => 0.07)

economic_lifetime = Dict(("asset1", "asset2") => 10, ("asset3", "asset4") => 15)

annualized_cost = Dict(
    (2022, ("asset1", "asset2")) => 135.671,
    (2021, ("asset3", "asset4")) => 153.918,
    (2021, ("asset1", "asset2")) => 123.338,
)

years = [2021, 2022]

investable_assets =
    Dict(2021 => [("asset1", "asset2"), ("asset3", "asset4")], 2022 => [("asset1", "asset2")])

salvage_value = calculate_salvage_value(
    discount_rate,
    economic_lifetime,
    annualized_cost,
    years,
    investable_assets,
)

# output

Dict{Tuple{Int64, Tuple{String, String}}, Float64} with 3 entries:
  (2022, ("asset1", "asset2")) => 964.325
  (2021, ("asset3", "asset4")) => 1202.24
  (2021, ("asset1", "asset2")) => 759.2
```
"""
function calculate_salvage_value(
    discount_rate,
    economic_lifetime,
    annualized_cost,
    years,
    investable_assets,
)
    # Create a dict of the years beyond the last milestone year
    end_of_horizon = maximum(years)
    salvage_value_set = Dict(
        (year, asset) => collect(end_of_horizon+1:year+economic_lifetime[asset]-1) for
        year in years for asset in investable_assets[year] if
        year + economic_lifetime[asset] - 1 ≥ end_of_horizon + 1
    )

    # Create a dict of salvage values
    salvage_value = Dict(
        (year, asset) => if (year, asset) in keys(salvage_value_set)
            annualized_cost[(year, asset)] * sum(
                1 / (1 + discount_rate[asset])^(year_alias - year) for
                year_alias in salvage_value_set[(year, asset)]
            )
        else
            0
        end for year in years for asset in investable_assets[year]
    )
    return salvage_value
end

"""
    calculate_weight_for_investment_discounts(social_rate,
                                              discount_year,
                                              salvage_value,
                                              investment_cost,
                                              years,
                                              investable_assets,
                                             )

Calculates the weight for investment discounts for each asset, both energy assets and transport assets.

# Arguments
- `social_rate::Float64`: A value with the social discount rate.
- `discount_year::Int64`: A value with the discount year for all the investments.
- `salvage_value::Dict`: A dictionary where the key is an tuple `(year, asset)` or `(year, (asset1, asset2))` for transport assets, and the value is the salvage value.
- `investment_cost::Dict`: A dictionary where the key is an tuple `(year, asset)` or `(year, (asset1, asset2))` for transport assets, and the value is the investment cost.
- `years::Array`: An array of years to be considered.
- `investable_assets::Dict`: A dictionary where the key is a year, and the value is an array of assets that are relevant for that year.

# Returns
- A `Dict` where the keys are tuples `(year, asset)` representing the year and the asset, and the values are the weights for investment discounts.

# Formula
The weight for investment discounts for each asset in year is calculated using the formula:

weight_for_investment_discounts =
    1 / (1 + social_rate)^(year - discount_year) *
    (1 - salvage_value[(year, asset)] / investment_cost[(year, asset)])

# Example for energy assets

```jldoctest
social_rate = 0.02

discount_year = 2000

salvage_value = Dict(
    (2021, "asset1") => 759.1978422,
    (2021, "asset2") => 1202.2339859,
    (2022, "asset1") => 964.3285406,
)

investment_cost = Dict(
    (2021, "asset1") => 1000,
    (2021, "asset2") => 1500,
    (2022, "asset1") => 1100,
    (2022, "asset2") => 1600,
)
years = [2021, 2022]

investable_assets = Dict(2021 => ["asset1", "asset2"], 2022 => ["asset1"])

weights = calculate_weight_for_investment_discounts(
    social_rate,
    discount_year,
    salvage_value,
    investment_cost,
    years,
    investable_assets,
)

# output

Dict{Tuple{Int64, String}, Float64} with 3 entries:
  (2021, "asset1") => 0.158875
  (2021, "asset2") => 0.130973
  (2022, "asset1") => 0.0797796
```

# Example for transport assets

```jldoctest
social_rate = 0.02

discount_year = 2000

salvage_value = Dict(
  (2022, ("asset1", "asset2")) => 964.325,
  (2021, ("asset3", "asset4")) => 1202.24,
  (2021, ("asset1", "asset2")) => 759.2,
)

investment_cost   = Dict((2021, ("asset1","asset2")) => 1000, (2021, ("asset3","asset4")) => 1500,
                         (2022, ("asset1","asset2")) => 1100, (2022, ("asset3","asset4")) => 1600)
years = [2021, 2022]

investable_assets = Dict(2021 => [("asset1","asset2"), ("asset3","asset4")],
                         2022 => [("asset1","asset2")])

weights = calculate_weight_for_investment_discounts(
    social_rate,
    discount_year,
    salvage_value,
    investment_cost,
    years,
    investable_assets,
)

# output

Dict{Tuple{Int64, Tuple{String, String}}, Float64} with 3 entries:
  (2022, ("asset1", "asset2")) => 0.0797817
  (2021, ("asset3", "asset4")) => 0.13097
  (2021, ("asset1", "asset2")) => 0.158874
```
"""
function calculate_weight_for_investment_discounts(
    social_rate,
    discount_year,
    salvage_value,
    investment_cost,
    years,
    investable_assets,
)
    weight_for_investment_discounts = Dict(
        (year, asset) =>
            1 / (1 + social_rate)^(year - discount_year) *
            (1 - salvage_value[(year, asset)] / investment_cost[(year, asset)]) for
        year in years for asset in investable_assets[year]
    )
    return weight_for_investment_discounts
end
