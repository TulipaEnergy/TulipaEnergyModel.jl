# Tutorial 9: Stochastic method

## Introduction 

Stochastic programming methods are used to model the uncertainty in long-term investment decisions explicitly by considering multiple scenarios. In a two-stage stochastic setting, the investment decision is the first stage decision and the operational decisions after uncertainty is realized represent the second stage.

The TulipaClustering.jl package allows the creation of blended Representative Periods (RPs) to reduce the size of the problem. A tutorial on this package is available under [Tutorial4](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/10-tutorials/15-clustering-rep-periods/)

In the stochastic setting, RPs can be clustered Per or Cross scenario. Here is the concept documentation for more detail: [Clustering per or Cross](https://tulipaenergy.github.io/TulipaClustering.jl/stable/20-concepts/#Clustering-Per-or-Cross)

## Previously in the TLC 

We reuse the instantiation from previous tutorials, and subsequently use the data of tutorial 9


```julia
using Pkg: Pkg
Pkg.activate(".")
Pkg.instantiate() # only if update packages
import TulipaIO as TIO
import TulipaEnergyModel as TEM #forces TEM. before calling functions
using DuckDB
using DataFrames
using Plots

```


