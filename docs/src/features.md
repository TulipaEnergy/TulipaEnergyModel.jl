# [Model Features](@id features)

This section explains the main features in the optimization model inside [TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl).

## [Flexible Time Resolution](@id flex-time-res)

Hourly resolution definition:

![Hourly Time Resolution](./figs/variable-time-resolution-1.png)

Variable time resolution definition:

![Variable Time Resolution](./figs/variable-time-resolution-2.png)

Storage balance

```math
\begin{aligned}
& storage\_balance_{phs,1,1:6}: \\
& \qquad storage\_level_{phs,1,1:6} = 4 \cdot 0.9 \cdot flow_{(wind,phs),1,1:4} \\
& \qquad \quad + 2 \cdot 0.9 \cdot flow_{(wind,phs),1,5:6} - \frac{3}{0.9} \cdot flow_{(phs,balance),1,1:3} \\
& \qquad \quad - \frac{3}{0.9} \cdot flow_{(phs,balance),1,4:6}
\end{aligned}
```
