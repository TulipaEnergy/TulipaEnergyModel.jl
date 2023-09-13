using TulipaEnergyModel
using Documenter

DocMeta.setdocmeta!(
    TulipaEnergyModel,
    :DocTestSetup,
    :(using TulipaEnergyModel);
    recursive = true,
)

makedocs(;
    modules = [TulipaEnergyModel],
    authors = "Abel Soares Siqueira <abel.s.siqueira@gmail.com> and contributors",
    repo = "https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/{commit}{path}#{line}",
    sitename = "TulipaEnergyModel.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Mathematical Formulation" => "mathematical-formulation.md",
        "How to Use" => "how-to-use.md",
        "API" => "api.md",
        "Tutorial" => "tutorial.md",
        "Reference" => "reference.md",
    ],
)

deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl", devbranch = "main")
