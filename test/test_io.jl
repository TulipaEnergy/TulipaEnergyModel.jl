@testset "Input validation" begin
    @testset "Make sure that input validation fails for bad files" begin
        dir = joinpath(INPUT_FOLDER, "tiny")
        @test_throws ArgumentError TulipaEnergyModel.read_csv_with_schema(
            joinpath(dir, "bad-assets-data.csv"),
            TulipaEnergyModel.AssetData,
        )
    end
end
