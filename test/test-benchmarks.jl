@testitem "Ensuring benchmark loads" setup = [CommonSetup] tags = [:integration, :fast] begin
    include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
    @test SUITE !== nothing
end

@testitem "Ensuring data can be read and create the internal structures" setup = [CommonSetup] tags =
    [:integration, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "../benchmark/EU/"))
    @test TulipaEnergyModel.create_internal_tables!(connection) === nothing
end
