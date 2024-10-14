using TulipaEnergyModel
using Documenter

DocMeta.setdocmeta!(TulipaEnergyModel, :DocTestSetup, :(using TulipaEnergyModel); recursive = true)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [TulipaEnergyModel],
    authors = "Diego A. Tejada-Arango <diego.tejadaarango@tno.nl>,Germán Morales-España <german.morales@tno.nl>,Lauren Clisby <lauren.clisby@tno.nl>,Ni Wang <ni.wang@tno.nl>,Abel Soares Siqueira <abel.s.siqueira@gmail.com>,Suvayu Ali <s.ali@esciencecenter.nl>,Laurent Soucasse <l.soucasse@esciencecenter.nl>,Greg Neustroev <G.Neustroev@tudelft.nl>",
    sitename = "TulipaEnergyModel.jl",
    format = Documenter.HTML(; canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl")
