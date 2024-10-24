```@meta
CurrentModule = TulipaEnergyModel
```

# [Welcome](@id home)

[TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) is an optimization model for the electricity market that can be coupled with other energy sectors (e.g., hydrogen, heat, natural gas, etc.). The optimization model determines the optimal investment and operation decisions for different types of assets (e.g., producers, consumers, conversion, storage, and transport). _TulipaEnergyModel.jl_ is developed in [Julia](https://julialang.org/) and depends on the [JuMP.jl](https://github.com/jump-dev/JuMP.jl) package.

## Tulipa in a Nutshell

### Example Questions

Tulipa can answer questions such as:

- How much flexible energy supply and demand is available? How much is needed in the future?
- How will different investment decisions impact the balance and generation mix of the energy system?
- Where will there be grid congestion in the future? How would placing [technology] at [location] impact congestion?
- How will [national/international] policy targets influence investment and dispatch?
- How will a future energy system handle different weather events (such as dunkelflaute)?

Not sure if Tulipa is right for your research? Feel free to ask in our [Discussions](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/discussions/categories/q-a)!

### Scope & Features

For modellers, here is a brief summary of Tulipa's scope and features. More details can be found in the [Concepts](@ref concepts) or [Formulation](@ref formulation).

- Optimisation Objective: Minimize total system cost for investment & dispatch
- Geographic scope: Flexible/Anywhere - Region/Country/Continent
- Energy carriers: Any/All - electricity, gas, H2, heat, etc
- Timespan: Any - Usually Yearly or Multi-year
- Time resolution: [Fully-flexible](@ref flex-time-res) - even mixing different resolutions (1-hr, 2-hr, 3-hr, etc) within a scenario
- Time abstraction: Blended representative periods
- Storage: [Short- and Long-term storage](@ref storage-modeling) constraints, even while using representative periods
- Solutions: Optimal & Near-optimal alternatives, using modelling to generate alternatives (MGA)

## Getting Started

To start using Tulipa for your research, check out our [How to Use](@ref how-to-use) section and [Tutorials](@ref tutorials).

For a more technical explanation, check out the [Concepts](@ref concepts) section, or dive into the [Mathematical Formulation](@ref formulation).

## [Bug reports and discussions](@id bugs-and-discussions)

If you think you have found a bug, feel free to open an [Issue](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/issues).
If you have a general question or idea, start a [Discussion](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/discussions).

## Contributing

If you want to contribute (awesome!), please read our [Contributing Guidelines](@ref contributing) and follow the setup in our [Developer Documentation](@ref developer).

## [License](@id license)

This content is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) License.

## Contributors

```@raw html
<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://abelsiqueira.com"><img src="https://avatars.githubusercontent.com/u/1068752?v=4?s=100" width="100px;" alt="Abel Soares Siqueira"/><br /><sub><b>Abel Soares Siqueira</b></sub></a><br /><a href="#code-abelsiqueira" title="Code">💻</a> <a href="#review-abelsiqueira" title="Reviewed Pull Requests">👀</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/datejada"><img src="https://avatars.githubusercontent.com/u/12887482?v=4?s=100" width="100px;" alt="Diego Alejandro Tejada Arango"/><br /><sub><b>Diego Alejandro Tejada Arango</b></sub></a><br /><a href="#code-datejada" title="Code">💻</a> <a href="#review-datejada" title="Reviewed Pull Requests">👀</a> <a href="#ideas-datejada" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-datejada" title="Research">🔬</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/g-moralesespana"><img src="https://avatars.githubusercontent.com/u/42405171?v=4?s=100" width="100px;" alt="Germán Morales"/><br /><sub><b>Germán Morales</b></sub></a><br /><a href="#research-g-moralesespana" title="Research">🔬</a> <a href="#ideas-g-moralesespana" title="Ideas, Planning, & Feedback">🤔</a> <a href="#fundingFinding-g-moralesespana" title="Funding Finding">🔍</a> <a href="#projectManagement-g-moralesespana" title="Project Management">📆</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/greg-neustroev"><img src="https://avatars.githubusercontent.com/u/32451432?v=4?s=100" width="100px;" alt="Greg Neustroev"/><br /><sub><b>Greg Neustroev</b></sub></a><br /><a href="#ideas-greg-neustroev" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-greg-neustroev" title="Research">🔬</a> <a href="#code-greg-neustroev" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://cris.vtt.fi/en/persons/juha-kiviluoma"><img src="https://avatars.githubusercontent.com/u/40472544?v=4?s=100" width="100px;" alt="Juha Kiviluoma"/><br /><sub><b>Juha Kiviluoma</b></sub></a><br /><a href="#ideas-jkiviluo" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-jkiviluo" title="Research">🔬</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/clizbe"><img src="https://avatars.githubusercontent.com/u/11889283?v=4?s=100" width="100px;" alt="Lauren Clisby"/><br /><sub><b>Lauren Clisby</b></sub></a><br /><a href="#code-clizbe" title="Code">💻</a> <a href="#review-clizbe" title="Reviewed Pull Requests">👀</a> <a href="#ideas-clizbe" title="Ideas, Planning, & Feedback">🤔</a> <a href="#projectManagement-clizbe" title="Project Management">📆</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/lsoucasse"><img src="https://avatars.githubusercontent.com/u/135331272?v=4?s=100" width="100px;" alt="Laurent Soucasse"/><br /><sub><b>Laurent Soucasse</b></sub></a><br /><a href="#ideas-lsoucasse" title="Ideas, Planning, & Feedback">🤔</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://www.alg.ewi.tudelft.nl/weerdt/"><img src="https://avatars.githubusercontent.com/u/1650785?v=4?s=100" width="100px;" alt="Mathijs de Weerdt"/><br /><sub><b>Mathijs de Weerdt</b></sub></a><br /><a href="#fundingFinding-mdeweerdt" title="Funding Finding">🔍</a> <a href="#projectManagement-mdeweerdt" title="Project Management">📆</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/gnawin"><img src="https://avatars.githubusercontent.com/u/125902905?v=4?s=100" width="100px;" alt="Ni Wang"/><br /><sub><b>Ni Wang</b></sub></a><br /><a href="#code-gnawin" title="Code">💻</a> <a href="#review-gnawin" title="Reviewed Pull Requests">👀</a> <a href="#ideas-gnawin" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-gnawin" title="Research">🔬</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://www.svrijn.nl"><img src="https://avatars.githubusercontent.com/u/8833517?v=4?s=100" width="100px;" alt="Sander van Rijn"/><br /><sub><b>Sander van Rijn</b></sub></a><br /><a href="#ideas-sjvrijn" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/suvayu"><img src="https://avatars.githubusercontent.com/u/229540?v=4?s=100" width="100px;" alt="Suvayu Ali"/><br /><sub><b>Suvayu Ali</b></sub></a><br /><a href="#code-suvayu" title="Code">💻</a> <a href="#review-suvayu" title="Reviewed Pull Requests">👀</a> <a href="#ideas-suvayu" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/gzclarence"><img src="https://avatars.githubusercontent.com/u/70965161?v=4?s=100" width="100px;" alt="Zhi"/><br /><sub><b>Zhi</b></sub></a><br /><a href="#ideas-gzclarence" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-gzclarence" title="Research">🔬</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/maaikeelgersma"><img src="https://avatars.githubusercontent.com/u/55436655?v=4?s=100" width="100px;" alt="maaikeelgersma"/><br /><sub><b>maaikeelgersma</b></sub></a><br /><a href="#ideas-maaikeelgersma" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-maaikeelgersma" title="Research">🔬</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
```
