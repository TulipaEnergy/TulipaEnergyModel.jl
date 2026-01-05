---
title: 'TulipaEnergyModel.jl: A Modelling Framework Breaking the Tradeoff Between Fidelity and Computational Load'
tags:
  - Julia
  - energy-system optimisation
  - unit commitment
  - multi-year investment
  - DC-OPF
  - seasonal storage
  - representative periods
  - flexible temporal resolution
authors:
    - given-names: Abel
      surname: Soares Siqueira
      email: abel.siqueira@esciencecenter.nl
      affiliation: 1
      orcid: "0000-0003-4451-281X"
    - given-names: Diego A.
      surname: Tejada-Arango
      email: diego.tejadaarango@tno.nl
      affiliation: 2, 6
      orcid: "0000-0002-3278-9283"
    - given-names: Grigory
      surname: Neustroev
      email: g.neustroev@tudelft.nl
      affiliation: 3
      orcid: "0000-0002-7706-7778"
    - given-names: Juha
      surname:  Kiviluoma
      email: juha.kiviluoma@nodal-tools.fi
      affiliation: 4
      orcid: "0000-0002-1299-9056"
    - given-names: Lauren
      surname: Clisby
      email: lauren.clisby@tno.nl
      affiliation: 2
      orcid: "0009-0008-7848-4144"
    - given-names: Maaike
      surname: Elgersma
      email: m.b.elgersma@tudelft.nl
      affiliation: 3
    - given-names: Ni
      surname: Wang
      email: ni.wang@tno.nl
      affiliation: 2
      orcid: "0000-0001-7037-7004"
    - given-names: Suvayu
      surname: Ali
      email: s.ali@esciencecenter.nl
      affiliation: 1
    - given-names: Zhi
      surname: Gao
      email: z.gao1@uu.nl
      affiliation: 5
      orcid: "0000-0002-3817-8037"
    - given-names: Mathijs M.
      surname: de Weerdt
      email: m.m.deweerdt@tudelft.nl
      affiliation: 3
      orcid: "0000-0002-0470-6241"
    - given-names: Germán
      surname: Morales-España
      email: german.morales@tno.nl
      affiliation: "2, 3"
      orcid: "0000-0002-6372-6197"
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
  - name: Nodal Tools, Finland
    index: 4
  - name: Utrecht University, Netherlands
    ror: 04pp8hn57
    index: 5
  - name: Universidad Pontificia Comillas
    ror: 017mdc710
    index: 6
date: 04 October 2025
bibliography: paper.bib
---

## Summary

`TulipaEnergyModel.jl` is a modelling framework for analysing investment and operational decisions of future energy systems through capacity expansion and dispatch optimisation. `TulipaEnergyModel.jl` is the main package of the Tulipa Energy ecosystem, and it is developed in [Julia](https://julialang.org) [@Julia] using [JuMP.jl](https://jump.dev) [@JuMP].
As a framework, Tulipa formulates models entirely based on input data. This allows users to analyse virtually any system using the generalised building blocks – production, consumption, conversion, storage, and transport.
TulipaEnergyModel.jl focuses on model quality and efficient implementation, allowing it to break the tradeoff between model fidelity and computational load through: tighter MIP formulations; exact LP reformulations with fewer constraints and variables; more accurate LP approximations; and flexible model fidelity across temporal, technological, and spatial dimensions.

## Statement of Need

Existing models and frameworks in Energy System Optimisation include [EnergyModelsX](https://github.com/EnergyModelsX) [@EnergyModelsX], [PowerModels](https://github.com/lanl-ansi/PowerModels.jl) [@PowerModels], [SpineOpt](https://www.tools-for-energy-system-modelling.org/) [@SpineOpt], [Sienna](https://www.nrel.gov/analysis/sienna) [@Sienna], [GenX](https://github.com/GenXProject/GenX) [@GenX], [PyPSA](https://pypsa.org) [@PyPSA], and [Calliope](https://github.com/calliope-project/calliope) [@Calliope].
However, they run into computational limits when solving large-scale problems and must resort to (over)simplifying the model to reduce computational burden. The common misconception is that the only strategy to speed up solving times without sacrificing model fidelity is through faster solvers or computers.
However, the strategy that is widely overlooked is improving the quality of the mathematical formulations, which increases model fidelity while simultaneously solving faster than standard formulations.
This insight inspired the development of TulipaEnergyModel.jl, with the core philosophy of advancing the state-of-the-art in formulation quality by: 1) lowering computational cost while maintaining model fidelity, by reducing the problem size [@Tejada2025], and by creating tighter mixed-integer programs (MIP) [@MoralesEspana2013]. 2) increasing model fidelity without extra computational cost, e.g., by developing more accurate linear programming (LP) approximations [@Elgersma2025; @gentile2016; @MoralesEspana2022]. Finally, 3) balancing computational burden with adaptive/flexible model fidelity, i.e., having different levels of detail in various parts of the model, in the temporal [@Gao2025], technological [@MoralesEspana2022] and spatial dimensions.
These modelling strategies offer significant computational benefits, especially when handling large-scale problems: covering a continent with multiple energy carriers, and optimising over decades while maintaining hourly resolution for key aspects (e.g., renewable generation).
TulipaEnergyModel.jl had to be developed from scratch to be able to include all of these modelling breakthroughs, since they alter the foundation and structure of the model.
Below, we present some of core modelling and software design innovations.

## Modelling Innovations

Two of the main innovations include:

1. Fully flexible temporal resolution [@Gao2025] for the assets/ flows,
2. Direct connections between assets [@Tejada2025].

The following example illustrates these concepts:

![Example of network with flexible resolution of assets and flows \label{fig:flexible-time-resolution}](images/flexible-time-resolution.png)

For the fully flexible temporal resolution, consider the 6-hour duration of this system. The flow between "H2" and "ccgt" has a resolution of 6 hours, while the flow between "ccgt" and "balance" is 1 hour. The resolution from "wind" to "phs" is 3 hours, and from "phs" to "balance" is irregular, a 4-hour block followed by a 2-hour block. Tulipa allows different temporal resolutions throughout the model, thereby reducing the number of variables and constraints. This feature can drastically speed up solving with little loss in accuracy [@Gao2025].

For the direct connection between assets, the storage “phs” is directly connected to the “wind“ to charge, and to “balance” to discharge. This for direct connection between assets completely avoids intermediate elements (connections/nodes), thereby eliminating unnecessary variables and constraints. Thus, accelerating solving times without any loss of accuracy [@Tejada2025].

TulipaEnergyModel.jl is fundamentally focused on high-quality mathematical formulations. The model also includes other key features such as seasonal storage modelling using representative periods [@Tejada2018; @greg2025], tight and compact MIP formulations for storage [@Elgersma2025], unit commitment [@MoralesEspana2013], and compact formulations for multi-year investment [@wang2025a; @wang2025b].

## Software Design Innovations

To accommodate flexible temporal resolution for assets and flows, many variables have a "time block" component instead of a "time step", and many variables and constraints have sparse indices.
To explain how this is implemented, revisit the system from Figure \ref{fig:flexible-time-resolution}.
In an hourly implementation, there would be variables such as $f_{(\text{H2},\text{ccgt}),t}$, $f_{(\text{phs},\text{balance}),t}$ for $t = 1,\dots,6$.
Instead, looking at the time blocks of each flow, there are $f_{(\text{H2},\text{ccgt}),1:6}$, $f_{(\text{phs},\text{balance}),1:4}$, and $f_{(\text{phs},\text{balance}),5:6}$.
In other words, this flow variable could be defined as

$$f_{e,b} \qquad \forall e \in E, b \in B(e),$$

where $E$ is the set of edges of the graph, and $B(e)$ is the set of time blocks for each edge.

Similarly, some constraints and expressions have their own time blocks (e.g., the balance constraints), and obtaining the coefficients of the flows involves matching indices and computing the intersections between time blocks.
Defining variables like this in JuMP leads to sparse indices, which are cumbersome and potentially slow.
It can also create performance pitfalls, such as the ["sum-if problem"](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/sum_if/), when trying to determine the coefficients of each flow in each balance constraint.

To improve the storage of these objects, Tulipa uses a tabular format to collect the indices of each variable, constraint, and expression.
Each row of the table stores the corresponding set of indices for each JuMP object, and the JuMP objects themselves are stored in a linearised way in an array.
Returning to the example system, the first three rows of the flow variable defined above are shown in Table \ref{tab:linearised}.

| id   | from asset   | to asset   | time block start   | time block end   |
| ---- | ------------ | ---------- | ------------------ | ---------------- |
| 1    | H2           | ccgt       | 1                  | 6                |
| 2    | phs          | balance    | 1                  | 4                |
| 3    | phs          | balance    | 5                  | 6                |

Table: "Example of linearised tabular indices of the `var_flow` table"\label{tab:linearised}

Storing the indices in tables avoids the sparse storage of JuMP objects, which can instead be stored in an array with their positions matching the IDs in the index tables.
Figure \ref{fig:indices} illustrates this method of storage.

![Representation of the storage of indices and JuMP objects \label{fig:indices}](images/indices-storage.png){height=60pt}

Another key design decision in Tulipa is handling data using a [DuckDB](https://duckdb.org) [@DuckDB] connection - from processing input data, to generating internal tables for model creation, to storing outputs.
This enables manipulating different data formats using DuckDB's capabilities (instead of Julia's), as well as decreasing data movement and duplication.

When creating variables and constraints, Tulipa can read the DuckDB tables row by row, reducing memory use compared to using an explicit Julia table, such as DataFrames.

Furthermore, using DuckDB for everything allows cleaner separation of the pipeline into (i) data ingestion and manipulation, (ii) indices creation, and (iii) model creation.
Figure \ref{fig:overview} summarises how Tulipa interacts with the DuckDB connection.

![Overview of Tulipa's integration with DuckDB \label{fig:overview}](images/tulipa-overview.jpg)

First, users can prepare their data using any tools they prefer before loading it into the DuckDB connection.
Then, the indices are created from the data in the DuckDB connection and saved back into it.
While this step currently occurs in Julia, many of the operations use SQL and could potentially be moved outside Julia.
Finally, the JuMP pipeline begins by reading the indices table and complementing the data as necessary, then creates the JuMP objects and generates the complete model, which is sent to the solver.
Tulipa is tested and benchmarked using the HiGHS [@HiGHS] solver, but other MIP solvers accepted by JuMP can be used as well.

## Acknowledgements

We thank Oscar Dowson for the initial suggestion to use DataFrames, which motivated us to use tabular storage for all indices.

This publication is part of the project NextGenOpt ESI.2019.008, which is financed by the Dutch Research Council (NWO) and supported by the Netherlands eScience Center NLeSC C 21.0226. This project was also supported by TNO's internal R&D. This research is also (partially) funded by the European Climate, Infrastructure and Environment Executive Agency under the European Union’s HORIZON Research and Innovation Actions under grant agreement no. 101095998.

## References
