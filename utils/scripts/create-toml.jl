using TulipaEnergyModel

input_files_folders = [
    [
        joinpath(@__DIR__, "..", "..", "test", "inputs", test_input) for test_input in [
            "Multi-year Investments",
            "Norse",
            "Storage",
            "Tiny",
            "UC-ramping",
            "Variable Resolution",
        ]
    ]
    joinpath(@__DIR__, "..", "..", "benchmark", "EU")
]

filename = "model_parameters.toml"
for path in (joinpath(folder, filename) for folder in input_files_folders)
    folder = dirname(path)
    open(path, "w") do io
        if basename(folder) == "Multi-year Investments"
            write(
                io,
                """
                model_discount_rate = 0.03
                model_discount_year = 2020
                """,
            )
        end
    end
end
