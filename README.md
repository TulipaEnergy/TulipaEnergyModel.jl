# TulipaEnergyModel

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://TulipaEnergy.github.io/TulipaEnergyModel.jl/stable)
[![In development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://TulipaEnergy.github.io/TulipaEnergyModel.jl/dev)
[![Build Status](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/workflows/Test/badge.svg)](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions)
[![Test workflow status](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Lint workflow Status](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/actions/workflows/Docs.yml?query=branch%3Amain)

[![Coverage](https://codecov.io/gh/TulipaEnergy/TulipaEnergyModel.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/TulipaEnergy/TulipaEnergyModel.jl)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.8363262.svg)](https://doi.org/10.5281/zenodo.8363262)

[![All Contributors](https://img.shields.io/github/all-contributors/TulipaEnergy/TulipaEnergyModel.jl?labelColor=5e1ec7&color=c0ffee&style=flat-square)](#contributors)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

This package provides an optimization model for the electricity market and its coupling with other energy sectors (e.g., hydrogen, heat, natural gas, etc.). The main objective is to determine the optimal investment and operation decisions for different types of assets (e.g., producers, consumers, conversions, storages, and transports).

## How to Cite

If you use TulipaEnergyModel.jl in your work, please cite using the reference given in [CITATION.cff](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/CITATION.cff).

## Installation

```julia-pkg
pkg> add TulipaEnergyModel
```

See the [documentation](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/) for details on the model and the package.

## Bug reports and discussions

If you think you have found a bug, feel free to open an [issue](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/issues).
If you have a general question or idea, start a discussion [here](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/discussions).

## Contributing

If you want to contribute (awesome!), please read our [Contributing Guidelines](@ref contributing) and follow the setup in our [Developer Documentation](@ref developer).

## License

This content is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) License.

---

## Contributors

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
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/suvayu"><img src="https://avatars.githubusercontent.com/u/229540?v=4?s=100" width="100px;" alt="Suvayu Ali"/><br /><sub><b>Suvayu Ali</b></sub></a><br /><a href="#code-suvayu" title="Code">💻</a> <a href="#review-suvayu" title="Reviewed Pull Requests">👀</a> <a href="#ideas-suvayu" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/gzclarence"><img src="https://avatars.githubusercontent.com/u/70965161?v=4?s=100" width="100px;" alt="Zhi"/><br /><sub><b>Zhi</b></sub></a><br /><a href="#ideas-gzclarence" title="Ideas, Planning, & Feedback">🤔</a> <a href="#research-gzclarence" title="Research">🔬</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
