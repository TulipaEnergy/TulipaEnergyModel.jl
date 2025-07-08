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
      affiliation: Netherlands eScience Center
      orcid: "https://orcid.org/0000-0003-4451-281X"
    - given-names: Diego A.
      surname: Tejada-Arango
      email: diego.tejadaarango@tno.nl
      affiliation: TNO
      orcid: "https://orcid.org/0000-0002-3278-9283"
    - given-names: Germán
      surname: Morales-España
      email: german.morales@tno.nl
      affiliation: TNO
      orcid: "https://orcid.org/0000-0002-6372-6197"
    - given-names: Grigory
      surname: Neustroev
      email: g.neustroev@tudelft.nl
      affiliation: Delft University of Technology
      orcid: "https://orcid.org/0000-0002-7706-7778"
    - given-names: Juha
      surname:  Kiviluoma
      email: Juha.Kiviluoma@vtt.fi
      affiliation: VTT Technical Research Centre of Finland
      orcid: "https://orcid.org/0000-0003-3425-0254"
    - given-names: Lauren
      surname: Clisby
      email: lauren.clisby@tno.nl
      affiliation: TNO
      orcid: "https://orcid.org/0009-0008-7848-4144"
    - given-names: Maaike
      surname: Elgersma
      email: m.b.elgersma@tudelft.nl
      affiliation: TU Delft
    - given-names: Ni
      surname: Wang
      email: ni.wang@tno.nl
      affiliation: TNO
      orcid: "https://orcid.org/0000-0001-7037-7004"
    - given-names: Suvayu
      surname: Ali
      email: s.ali@esciencecenter.nl
      affiliation: Netherlands eScience Center
    - given-names: Zhi
      surname: Gao
      email: z.gao1@uu.nl
      affiliation: Utrecht University
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
TulipaEnergyModel.jl is developed in [Julia](CITE) and depends on the [JuMP.jl](CITE) package.

TulipaEnergyModel.jl is the main package of the Tulipa Energy ecosystem.
It provides a cutting-edge energy system model based on the user's data.
Our main use case is modeling energy distribution in Europe, but there are no constraints preventing the user from extending to other use cases.

One of the main features of TulipaEnergyModel is that it accepts a _fully flexible resolution_ (cite) for the assets and flows.
In other words, the resolution at which the variables are defined don't have to be multiples of one another.
As a short example, consider the following example:

![Example of network with flexible resolution of assets](docs/src/figs/variable-time-resolution-2.png)

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

## Statement of need

(Energy-field related motivation).

There are multiple packages and frameworks related to Energy System Optimisation in Julia and other languages.
A few examples in the Julia and Python realm are [EnergyModelsX](ref), [PowerModels](ref) [SpineOpt](ref), [GenX](ref), [PyPSA](ref), and [Calliope](ref).

Despite the large array of options, we still felt necessary to develop Tulipa from the ground up due to the use of the fully flexible resolution mentioned above.
This changes all model structures in ways that cannot be easily adapted to existing models.

## Acknowledgements

## References
