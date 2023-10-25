@testset "Input validation" begin
    @testset "Make sure that input validation fails for bad files" begin
        dir = joinpath(INPUT_FOLDER, "Tiny")
        @test_throws ArgumentError TulipaEnergyModel.read_csv_with_schema(
            joinpath(dir, "bad-assets-data.csv"),
            TulipaEnergyModel.AssetData,
        )
    end
end

@testset "Graph structure" begin
    @testset "Graph structure is correct" begin
        dir = joinpath(INPUT_FOLDER, "Tiny")
        graph =
            create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))

        @test Graphs.nv(graph) == 6
        @test Graphs.ne(graph) == 5
        @test collect(Graphs.edges(graph)) ==
              [Graphs.Edge(e) for e in [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6)]]
    end
end
