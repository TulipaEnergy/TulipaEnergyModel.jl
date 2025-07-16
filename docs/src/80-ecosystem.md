# [Tulipa Ecosystem](@id ecosystem)

```@index
Pages = ["80-ecosystem.md"]
```

There are multiple packages in the Tulipa ecosystem, which you can find on the [TulipaEnergy](https://github.com/TulipaEnergy) organisation page.
Other packages have minimal documentation, so the documentation is concentrated in the TulipaEnergyModel repository. (The docs you are currently reading!)

Here's an overview:

- [TulipaEnergyModel](https://github.com/TulipaEnergy/TulipaEnergyModel.jl): The main package that takes data in Tulipa Format, produces the problem formulation, and sends the problem to the chosen solver.
- [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl): A pre-processing package that chooses representative periods for clustering data and produces the clusters and mapping.
- [TulipaProfileFitting](https://github.com/TulipaEnergy/TulipaProfileFitting.jl): A pre-processing package that fits (renewable) time series profiles from historical data to future target capacity factors.
- [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl): A data-handling tool that communicates between Julia and DuckDB to manage data-handling for TulipaEnergyModel. It also includes convenience functions to help users build data processing pipelines using minimal SQL.
- [TulipaVisualizer](https://github.com/TulipaEnergy/TulipaVisualizer): A (prototype) visualisation dashboard for analysts to explore results.
- [NearOptimalAlternatives](https://github.com/TulipaEnergy/NearOptimalAlternatives.jl): A post-optimisation package that uses methods such as Modelling to Generate Alternatives (MGA) to generate alternative solutions with objective function values near the optimal, but with output variables (solutions) as different from the optimal solution as possible.
- [excel2tulipa](https://github.com/TulipaEnergy/excel2tulipa): A convenience package for importing data from Excel to DuckDB database files - only requiring the user to fill in a file that specifies the mapping from one to the other.

Some case studies also have repositories, which are open for others to view and get ideas!
