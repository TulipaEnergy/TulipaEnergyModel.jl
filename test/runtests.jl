using CSV: CSV
using DataFrames: DataFrames, DataFrame
using DuckDB: DuckDB, DBInterface
using GLPK: GLPK
using HiGHS: HiGHS
using JuMP: JuMP
using MathOptInterface: MathOptInterface
using Test: Test, @test, @testset, @test_throws, @test_logs
using TOML: TOML
using TulipaEnergyModel: TulipaEnergyModel
using TulipaIO: TulipaIO

# Folders names
const INPUT_FOLDER = joinpath(@__DIR__, "inputs")
const OUTPUT_FOLDER = joinpath(@__DIR__, "outputs")
if !isdir(OUTPUT_FOLDER)
    mkdir(OUTPUT_FOLDER)
end

include("utils.jl")

#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".
=#
for (root, dirs, files) in walkdir(@__DIR__)
    for file in files
        if isnothing(match(r"^test-.*\.jl$", file))
            continue
        end
        title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
        @testset "$title" begin
            # include(file)
        end
    end
end

# Other general tests that don't need their own file
# @testset "Ensuring benchmark loads" begin
#     include(joinpath(@__DIR__, "..", "benchmark", "benchmarks.jl"))
#     @test SUITE !== nothing
# end
#
# @testset "Ensuring data can be read and create the internal structures" begin
#     connection = DBInterface.connect(DuckDB.DB)
#     _read_csv_folder(connection, joinpath(@__DIR__, "../benchmark/EU/"))
#     TulipaEnergyModel.create_internal_tables!(connection)
# end

@testset "Ensuring model.mps stays the same" begin
    model_mps_folder = joinpath(@__DIR__, "..", "benchmark", "model-mps-folder")

    ctx(str, i, n = 3) = begin
        imin = max(1, i - n)
        imax = min(length(str), i + n)
        str[imin:imax]
    end

    if isdir("tmpdir")
        rm("tmpdir"; force = true, recursive = true)
    end
    mkdir("tmpdir")

    for folder in readdir("inputs"; join = true)
        isdir(folder) || continue # excluding files that are not test folder
        existing_mps = joinpath(model_mps_folder, basename(folder) * ".mps")
        @assert isfile(existing_mps)

        @testset "Comparing .mps of $(basename(folder))" begin
            con = DBInterface.connect(DuckDB.DB)
            schemas = TulipaEnergyModel.schema_per_table_name
            TulipaIO.read_csv_folder(con, folder; schemas)
            # model_file_name = joinpath(mktempdir(), basename(folder) * ".mps")
            model_file_name = joinpath("tmpdir", basename(folder) * ".mps")
            TulipaEnergyModel.run_scenario(con; model_file_name, show_log = false)
            @assert isfile(model_file_name)

            existing_lines = sort(readlines(existing_mps))
            new_lines = sort(readlines(model_file_name))
            if existing_lines != new_lines
                zipped_lines = zip(sort(readlines(existing_mps)), sort(readlines(model_file_name)))
                for (i, (existing_line, new_line)) in enumerate(zipped_lines)
                    unmatched = findall(collect(existing_line) .!= collect(new_line))
                    if length(unmatched) > 0
                        @warn "$i: $unmatched" existing_line[unmatched] new_line[unmatched]
                        j = unmatched[1]
                        @warn "Context" ctx(existing_line, j) ctx(new_line, j)
                    end
                end
            end
        end
    end
end
