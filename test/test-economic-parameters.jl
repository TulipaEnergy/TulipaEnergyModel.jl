@testset "calculate_annualized_cost tests" begin
    discount_rate = Dict(
        (2021, "asset1") => 0.05,
        (2021, "asset2") => 0.07,
        (2022, "asset1") => 0.06,
        (2022, "asset2") => 0.08,
    )

    economic_lifetime = Dict(
        (2021, "asset1") => 10,
        (2021, "asset2") => 15,
        (2022, "asset1") => 12,
        (2022, "asset2") => 20,
    )

    investment_cost = Dict(
        (2021, "asset1") => 1000,
        (2021, "asset2") => 1500,
        (2022, "asset1") => 1100,
        (2022, "asset2") => 1600,
    )
    years = [2021, 2022]

    investable_assets = Dict(2021 => ["asset1", "asset2"], 2022 => ["asset1", "asset2"])

    expected_output = Dict(
        (2022, "asset2") => 150.89216121948235,
        (2021, "asset1") => 123.33769044329202,
        (2021, "asset2") => 153.91769817898106,
        (2022, "asset1") => 123.77804935729239,
    )

    result = calculate_annualized_cost(
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
