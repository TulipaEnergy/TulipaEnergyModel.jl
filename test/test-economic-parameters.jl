@testset "calculate_annualized_cost tests" begin
    discount_rate = Dict("asset1" => 0.05, "asset2" => 0.07)

    economic_lifetime = Dict("asset1" => 10, "asset2" => 15)

    investment_cost = Dict(
        (2021, "asset1") => 1000,
        (2021, "asset2") => 1500,
        (2022, "asset1") => 1100,
        (2022, "asset2") => 1600,
    )
    years = [2021, 2022]

    investable_assets = Dict(2021 => ["asset1", "asset2"], 2022 => ["asset1"])

    expected_output = Dict(
        (2021, "asset1") => 123.3376904,
        (2021, "asset2") => 153.9176982,
        (2022, "asset1") => 135.6714595,
    )

    result = TulipaEnergyModel.calculate_annualized_cost(
        discount_rate,
        economic_lifetime,
        investment_cost,
        years,
        investable_assets,
    )

    for key in keys(expected_output)
        @test result[key] ≈ expected_output[key] atol = 1e-6
    end
end

@testset "calculate_salvage_value tests" begin
    discount_rate = Dict("asset1" => 0.05, "asset2" => 0.07)

    economic_lifetime = Dict("asset1" => 10, "asset2" => 15)

    annualized_cost = Dict(
        (2021, "asset1") => 123.3376904,
        (2021, "asset2") => 153.9176982,
        (2022, "asset1") => 135.6714595,
    )

    years = [2021, 2022]

    investable_assets = Dict(2021 => ["asset1", "asset2"], 2022 => ["asset1"])

    expected_output = Dict(
        (2021, "asset1") => 759.1978422,
        (2021, "asset2") => 1202.2339859,
        (2022, "asset1") => 964.3285406,
    )

    result = TulipaEnergyModel.calculate_salvage_value(
        discount_rate,
        economic_lifetime,
        annualized_cost,
        years,
        investable_assets,
    )

    for key in keys(expected_output)
        @test result[key] ≈ expected_output[key] atol = 1e-6
    end
end

@testset "calculate_weight_for_investment_discounts tests" begin
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

    expected_output = Dict(
        (2021, "asset1") => 0.158875,
        (2021, "asset2") => 0.130973,
        (2022, "asset1") => 0.0797796,
    )

    result = TulipaEnergyModel.calculate_weight_for_investment_discounts(
        social_rate,
        discount_year,
        salvage_value,
        investment_cost,
        years,
        investable_assets,
    )

    for key in keys(expected_output)
        @test result[key] ≈ expected_output[key] atol = 1e-6
    end
end
