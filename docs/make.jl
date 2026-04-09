using TulipaEnergyModel
using Documenter

DocMeta.setdocmeta!(TulipaEnergyModel, :DocTestSetup, :(using TulipaEnergyModel); recursive = true)

const tutorials = [
    joinpath("10-tutorials", file) for
    file in readdir(joinpath(@__DIR__, "src", "10-tutorials")) if splitext(file)[2] == ".md"
]

const user_guide = [
    joinpath("20-user-guide", file) for
    file in readdir(joinpath(@__DIR__, "src", "20-user-guide")) if splitext(file)[2] == ".md"
]

const scientific_foundation = [
    joinpath("40-scientific-foundation", file) for
    file in readdir(joinpath(@__DIR__, "src", "40-scientific-foundation")) if
    splitext(file)[2] == ".md"
]

const contributing = [
    joinpath("90-contributing", file) for
    file in readdir(joinpath(@__DIR__, "src", "90-contributing")) if splitext(file)[2] == ".md"
]

# When building docs for a tagged release (e.g., refs/tags/v0.21.0), replace all
# GitHub links pointing to blob/main or tree/main with version-specific links so
# that the deployed documentation always references the exact same code version.
# For main-branch builds and pull-request previews the links are left unchanged.
const github_ref_slug = let
    ref = get(ENV, "GITHUB_REF", "")
    startswith(ref, "refs/tags/") ? replace(ref, r"^refs/tags/" => "") : "main"
end

# Collect files that were modified so they can be restored after makedocs.
modified_files = Tuple{String,String}[]

if github_ref_slug != "main"
    for (root, _dirs, files) in walkdir(joinpath(@__DIR__, "src"))
        for file in files
            endswith(file, ".md") || continue
            path = joinpath(root, file)
            original = read(path, String)
            modified = replace(
                original,
                r"(https://github\.com/TulipaEnergy/TulipaEnergyModel\.jl/(?:blob|tree)/)main/" =>
                    SubstitutionString("\\1$(github_ref_slug)/"),
            )
            if original != modified
                write(path, modified)
                push!(modified_files, (path, original))
            end
        end
    end
end

try
    makedocs(;
        modules = [TulipaEnergyModel],
        authors = "Abel Soares Siqueira <abel.s.siqueira@gmail.com>,Diego A. Tejada-Arango <diego.tejadaarango@tno.nl>,Germán Morales-España <german.morales@tno.nl>,Grigory Neustroev <G.Neustroev@tudelft.nl>,Juha Kiviluoma <Juha.Kiviluoma@vtt.fi>,Lauren Clisby <lauren.clisby@tno.nl>,Maaike Elgersma <m.b.elgersma@tudelft.nl>,Ni Wang <ni.wang@tno.nl>,Suvayu Ali <s.ali@esciencecenter.nl>,Zhi Gao <z.gao1@uu.nl>",
        sitename = "TulipaEnergyModel.jl",
        format = Documenter.HTML(;
            canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl",
        ),
        pages = [
            "index.md"
            "Tutorials" => tutorials
            "User Guide" => user_guide
            "30-concepts.md"
            "Scientific Foundation" => scientific_foundation
            "70-reference.md"
            "80-ecosystem.md"
            "Contributing" => contributing
        ],
    )
finally
    # Always restore the original source files, whether makedocs succeeded or failed.
    for (path, original) in modified_files
        write(path, original)
    end
end

env_push_preview = get(ENV, "PUSH_PREVIEW", "false")
push_preview = tryparse(Bool, env_push_preview)
if isnothing(push_preview)
    @warn """Couldn't parse '$env_push_preview' into a Bool"""
    push_preview = false
end
deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl", push_preview)
