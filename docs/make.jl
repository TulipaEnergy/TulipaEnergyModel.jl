using TulipaEnergyModel
using Documenter

DocMeta.setdocmeta!(TulipaEnergyModel, :DocTestSetup, :(using TulipaEnergyModel); recursive = true)

makedocs(;
    modules = [TulipaEnergyModel],
    repo = "https://github.com/TulipaEnergy/TulipaEnergyModel.jl.git",
    authors = "Abel Soares Siqueira <abel.s.siqueira@gmail.com> and contributors",
    sitename = "TulipaEnergyModel.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl",
        edit_link = "main",
        assets = ["assets/style.css"],
    ),
    pages = [
        "Home" => "index.md",
        "Features" => "features.md",
        "Mathematical Formulation" => "formulation.md",
        "How to Use" => "how-to-use.md",
        "Tutorials" => "tutorials.md",
        "API" => "api.md",
        "Reference" => "reference.md",
    ],
)

deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl", devbranch = "main")
