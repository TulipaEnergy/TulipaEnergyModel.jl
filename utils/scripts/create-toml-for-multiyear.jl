path = joinpath(@__DIR__, "..", "..", "test/inputs/Multi-year Investments/model_parameters.toml")
open(path, "w") do io
    write(
        io,
        """
        model_discount_rate = 0.03
        model_discount_year = 2020
        """,
    )
end
