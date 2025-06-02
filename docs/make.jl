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
    authors = "Abel Soares Siqueira <abel.s.siqueira@gmail.com>,Diego A. Tejada-Arango <diego.tejadaarango@tno.nl>,Germán Morales-España <german.morales@tno.nl>,Grigory Neustroev <G.Neustroev@tudelft.nl>,Juha Kiviluoma <Juha.Kiviluoma@vtt.fi>,Lauren Clisby <lauren.clisby@tno.nl>,Maaike Elgersma <m.b.elgersma@tudelft.nl>,Ni Wang <ni.wang@tno.nl>,Suvayu Ali <s.ali@esciencecenter.nl>,Zhi Gao <z.gao1@uu.nl>",
    repo = "https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/{commit}{path}#{line}",
    sitename = "TulipaEnergyModel.jl",
    format = Documenter.HTML(; canonical = "https://TulipaEnergy.github.io/TulipaEnergyModel.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/TulipaEnergy/TulipaEnergyModel.jl")
