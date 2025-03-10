using Base: SimpleLogger
# Run from project folder with
#
#   julia --project=. utils/scripts/model-mps-update.jl
#
# or
#
#   julia --project=<project_root> <project_root>/utils/scripts/model-mps-update.jl
#
include("model-mps-common.jl")
using Logging

root_folder = joinpath(@__DIR__, "..", "..")

function compare_mps(existing_mps_folder)
    test_inputs = joinpath(root_folder, "test", "inputs")

    for folder in filter(isdir, readdir(test_inputs; join = true))
        existing_mps_file = joinpath(existing_mps_folder, basename(folder) * ".mps")
        @assert isfile(existing_mps_file)

        new_mps_folder = mktempdir()
        new_mps_file = joinpath(new_mps_folder, basename(folder) * ".mps")

        no_issues = true

        @info """New comparison
            Comparing files
            - $existing_mps_file
            - $new_mps_file"""

        @info "Create mps for $folder in $new_mps_folder"
        create_mps(folder, new_mps_folder)
        @assert isfile(new_mps_file)

        existing_lines = readlines(existing_mps_file)
        new_lines = readlines(new_mps_file)

        if length(existing_lines) != length(new_lines)
            @error "Files don't have the same size"
        else
            zipped_lines = zip(existing_lines, new_lines)

            for (line_number, (existing_line, new_line)) in enumerate(zipped_lines)
                existing_words = split(existing_line)
                new_words = split(new_line)

                line_has_issues = false

                # Finding each different word
                for (existing_word, new_word) in zip(existing_words, new_words)
                    existing_word_as_float = tryparse(Float64, existing_word)
                    new_word_as_float = tryparse(Float64, new_word)

                    if existing_word_as_float === new_word_as_float === nothing # Both words are not Float64
                        # Compare their strings
                        if existing_word != new_word
                            line_has_issues = true
                        end
                    elseif (existing_word_as_float isa Float64 && new_word_as_float isa Float64) # Both words are Float64
                        # Compare whether they have approximately the same value
                        a, b = existing_word_as_float, new_word_as_float
                        if !isapprox(a, b; atol = 1e-12, rtol = 1e-8) # |a - b| ≤ max(atol, rtol * max{|a|, |b|})
                            line_has_issues = true
                        end
                    else # Words have different types
                        line_has_issues = true
                    end
                end

                if line_has_issues
                    no_issues = false
                    @error """Line $line_number"
                    ..Existing: '$existing_line'
                    .......New: '$new_line'"""
                end
            end
        end

        if no_issues
            @info "No difference found"
        end
    end

    return nothing
end

existing_mps_folder = joinpath(root_folder, "benchmark", "model-mps-folder")
compare_mps(existing_mps_folder)
