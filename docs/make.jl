using TulipaEnergyModel
using Documenter

DocMeta.setdocmeta!(TulipaEnergyModel, :DocTestSetup, :(using TulipaEnergyModel); recursive = true)

# const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
# const numbered_pages = [
#     file for file in readdir(joinpath(@__DIR__, "src")) if
#     file != "index.md" && splitext(file)[2] == ".md"
# ]

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

makedocs(;
    modules = [TulipaEnergyModel],
    authors = "Abel Soares Siqueira <abel.s.siqueira@gmail.com>,Diego A. Tejada-Arango <diego.tejadaarango@tno.nl>,Germán Morales-España <german.morales@tno.nl>,Grigory Neustroev <G.Neustroev@tudelft.nl>,Juha Kiviluoma <Juha.Kiviluoma@vtt.fi>,Lauren Clisby <lauren.clisby@tno.nl>,Maaike Elgersma <m.b.elgersma@tudelft.nl>,Ni Wang <ni.wang@tno.nl>,Suvayu Ali <s.ali@esciencecenter.nl>,Zhi Gao <z.gao1@uu.nl>",
    sitename = "TulipaEnergyModel.jl",
    format = Documenter.HTML(; canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl"),
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

deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl")
