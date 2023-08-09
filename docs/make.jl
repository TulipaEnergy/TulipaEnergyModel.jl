using TulipaBulb
using Documenter

DocMeta.setdocmeta!(TulipaBulb, :DocTestSetup, :(using TulipaBulb); recursive=true)

makedocs(;
    modules=[TulipaBulb],
    authors="Abel Soares Siqueira <abel.s.siqueira@gmail.com> and contributors",
    repo="https://github.com/TNO-Tulipa/TulipaBulb.jl/blob/{commit}{path}#{line}",
    sitename="TulipaBulb.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://TNO-Tulipa.github.io/TulipaBulb.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/TNO-Tulipa/TulipaBulb.jl",
    devbranch="main",
)
