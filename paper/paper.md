---
title: 'TulipaEnergyModel.jl: Energy system optimisation with fully flexible resolution'
tags:
  - Julia
  - energy-system optimisation
  - unit commitment
  - representative periods
  - flexible resolution
authors:
    - given-names: Abel
      surname: Soares Siqueira
      email: abel.siqueira@esciencecenter.nl
      affiliation: 1
      orcid: "https://orcid.org/0000-0003-4451-281X"
    - given-names: Diego A.
      surname: Tejada-Arango
      email: diego.tejadaarango@tno.nl
      affiliation: 2
      orcid: "https://orcid.org/0000-0002-3278-9283"
    - given-names: Germán
      surname: Morales-España
      email: german.morales@tno.nl
      affiliation: 2
      orcid: "https://orcid.org/0000-0002-6372-6197"
    - given-names: Grigory
      surname: Neustroev
      email: g.neustroev@tudelft.nl
      affiliation: 3
      orcid: "https://orcid.org/0000-0002-7706-7778"
    - given-names: Juha
      surname:  Kiviluoma
      email: Juha.Kiviluoma@vtt.fi
      affiliation: 4
      orcid: "https://orcid.org/0000-0003-3425-0254"
    - given-names: Lauren
      surname: Clisby
      email: lauren.clisby@tno.nl
      affiliation: 2
      orcid: "https://orcid.org/0009-0008-7848-4144"
    - given-names: Maaike
      surname: Elgersma
      email: m.b.elgersma@tudelft.nl
      affiliation: 3
    - given-names: Ni
      surname: Wang
      email: ni.wang@tno.nl
      affiliation: 2
      orcid: "https://orcid.org/0000-0001-7037-7004"
    - given-names: Suvayu
      surname: Ali
      email: s.ali@esciencecenter.nl
      affiliation: 1
    - given-names: Zhi
      surname: Gao
      email: z.gao1@uu.nl
      affiliation: 5
      orcid: "https://orcid.org/0000-0002-3817-8037"
affiliations:
  - name: Netherlands eScience Center, Netherlands
    ror: 00rbjv475
    index: 1
  - name: TNO - Netherlands Organisation for Applied Scientific Research, Netherlands
    ror: 01bnjb948
    index: 2
  - name: Delft University of Technology, Netherlands
    ror: 02e2c7k09
    index: 3
  - name: VTT Technical Research Centre of Finland, Netherlands
    ror: 04b181w54
    index: 4
  - name: Utrecht University, Netherlands
    ror: 04pp8hn57
    index: 5
date: 23 May 2025
bibliography: paper.bib
---

## Summary

`TulipaEnergyModel.jl` is an optimization model for the electricity market that can be coupled with other energy sectors (e.g., hydrogen, heat, natural gas, etc.).
The optimization model determines the optimal investment and operation decisions for different types of assets (e.g., producers, consumers, conversion, storage, and transport).
TulipaEnergyModel.jl is developed in [Julia](https://julialang.org) [@Julia] and depends on the [JuMP.jl](https://jump.dev) [@JuMP] package.

TulipaEnergyModel.jl is the main package of the Tulipa Energy ecosystem.
It provides a cutting-edge energy system model based on the user's data.
Our main use case is modeling energy distribution in Europe, but there are no constraints preventing the user from extending to other use cases.

One of the main features of TulipaEnergyModel is that it accepts a _fully flexible resolution_ (cite) for the assets and flows.
In other words, the resolution at which the variables are defined don't have to be multiples of one another.
As a short example, consider the following example:

![Example of network with flexible resolution of assets and flows](images/flexible-time-resolution.png)

In the example, we look at 6 hours of a network. The flow between "H2" and "ccgt" has a resolution of 6 hours (i.e., the whole period), while from "ccgt" to the "balance", the resolution is 1 hour.
The resolution from "wind" to "phs" is 3 hours, and the resolution from "phs" to "balance" is not regular, starting with a 4 hours block and then a 2 hours block.
All these "time blocks" are handled by the Tulipa energy model to allow for more or less detailed solutions.
This implies that less variables and constraints are created, ensuring a faster solving speed, with little loss in accuracy.
See (cite) for more details on the research behind fully flexible resolution.

Another feature of the Tulipa model is the use of representative periods (cite), supported by another package in our ecosystem, `TulipaClustering.jl`.
The representative periods are obtained by clustering the asset profiles (time series) from the full time frame to a much smaller one.
For instance, instead of using a full year with 8760 hours (365 periods of 24 hours each), we can choose to have 30 representative periods of 24 hours each.
These representative periods will be computed using `TulipaClustering.jl` so that each of the 365 original periods are replaced by a combination of the 30 representatives.
Now, we can model within representative periods (30 periods of 24 hours each), and across periods (365 periods).
Either way, we have a much smaller number of variables, making our model easier to solve.
See (cite) for more details on the research behind representative periods.

One main design choice of Tulipa is that data is passed (and kept) in a [DuckDB](https://duckdb.org) [@DuckDB] connection.
This enables us to handle different data formats by relying on DuckDB's capabilities, instead of specific Julia capabilities.
Furthermore, this separates most of the data manipulation from the model manipulation, allowing users to separately create the necessary input data from whatever platform they are more comfortable with.

Due to the flexible resolution of assets and flows, many of our variables have a "time block" component, instead of a "time step" component.
Since different assets and flows can have different time resolutions, the indices of many of our variables and constraints are sparse.
To better explain this feature, look again at Fig. X and ignore years and representative periods.
In an hourly implementation, we would have variables such as $f_{(\text{H2},\text{ccgt}),t}$, $f_{(\text{phs},\text{balance}),t}$ for $t = 1,\dots,6$.
Instead, looking at the time blocks of each flow, we have $f_{(\text{H2},\text{ccgt}),1:6}$ and $f_{(\text{phs},\text{balance}),b}$ for $b = 1\!:\!4, 5\!:\!6$.
In other words, this flow variable can be defined as

$$f_{e,b} \qquad \forall e \in E, b \in B(e),$$

where $E$ is the set of edges of the graph, and $B(e)$ is the set of time blocks for this edge.

To improve efficiency of the model, we use a linearized tabular format for the sets of each variable (and constraint).
For the flow variable as described above, could look like the following:

| id | from asset | to asset | time block start | time block end |
|----|------------|----------|------------------|----------------|
|  1 | h2 | ccgt | 1 | 6 |
|  2 | phs | balance | 1 | 4 |
|  3 | phs | balance | 5 | 6 |

Table: "Simplified example of the `var_flow` table"\label{tab:linearized}

We decided to also use DuckDB tables as the main format to keep these indices.
This decreases data movement by keeping everything in DuckDB.
The JuMP variables themselves are created and kept in memory during the program execution.
A single vector of variables is created, with each element corresponding to a row of the `var_flow` table.

## Statement of need

(Energy-field related motivation).

There are multiple packages and frameworks related to Energy System Optimisation in Julia and other languages.
A few examples in the Julia and Python realm are [EnergyModelsX](https://github.com/EnergyModelsX) [@EnergyModelsX], [PowerModels](https://github.com/lanl-ansi/PowerModels.jl) [@PowerModels], [SpineOpt](https://www.tools-for-energy-system-modelling.org/) [@SpineOpt], [Sienna](https://www.nrel.gov/analysis/sienna) [@Sienna], [GenX](https://github.com/GenXProject/GenX) [@GenX], [PyPSA](https://pypsa.org) [@PyPSA], and [Calliope](https://github.com/calliope-project/calliope) [@Calliope].

Despite the large array of options, we still felt necessary to develop Tulipa from the ground up due to the use of specific features already included and future developments.
This changes all model structures in ways that cannot be easily adapted to existing models.

## Acknowledgements

## References
