# [Model Features](@id features)

This section explains the main features in the optimization model inside [TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl).

## [Flexible Time Resolution](@id flex-time-res)

Hourly resolution definition:

![Hourly Time Resolution](./figs/variable-time-resolution-1.png)

Variable time resolution definition:

![Variable Time Resolution](./figs/variable-time-resolution-2.png)

### Storage balance

```math
\begin{aligned}
& storage\_balance_{phs,1,1:6}: \\
& \qquad storage\_level_{phs,1,1:6} = 4 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),1,1:4} \\
& \qquad \quad + 2 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),1,5:6} - \frac{3}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),1,1:3} \\
& \qquad \quad - \frac{3}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),1,4:6}
\end{aligned}
```

### Consumer balance

```math
\begin{aligned}
& consumer\_balance_{demand,1,1:3}: \\
& \qquad 3 \cdot flow_{(balance,demand),1,1:3} = p^{peak\_demand}_{demand} \cdot \sum_{k=1}^{3} p^{profile}_{demand,1,k} \\
& consumer\_balance_{demand,1,4:6}: \\
& \qquad 3 \cdot flow_{(balance,demand),1,4:6} = p^{peak\_demand}_{demand} \cdot \sum_{k=4}^{6} p^{profile}_{demand,1,k} \\
\end{aligned}
```

### Hub balance

```math
\begin{aligned}
& hub\_balance_{balance,1,1:4}: \\
& \qquad \sum_{k=1}^{4} flow_{(ccgt,balance),1,k} + 4 \cdot flow_{(wind,balance),1,1:4} \\
& \qquad + 3 \cdot flow_{(phs,balance),1,1:3} + 1 \cdot flow_{(phs,balance),1,4:6} \\
& \qquad - 3 \cdot flow_{(balance,demand),1,1:3} - 1 \cdot flow_{(balance,demand),1,4:6} = 0 \\
& hub\_balance_{balance,1,5:6}: \\
& \qquad \sum_{k=5}^{6} flow_{(ccgt,balance),1,k} + 2 \cdot flow_{(wind,balance),1,5:6} \\
& \qquad + 2 \cdot flow_{(phs,balance),1,4:6} - 2 \cdot flow_{(balance,demand),1,4:6} = 0 \\
\end{aligned}
```

### Conversion balance

```math
\begin{aligned}
& conversion\_balance_{ccgt,1,1:6}: \\
& 6 \cdot p^{eff}_{(H2,ccgt)} \cdot flow_{(H2,ccgt),1,1:6} = \frac{1}{p^{eff}_{(ccgt,balance)}} \sum_{k=1}^{6} flow_{(ccgt,balance),1,k}  \\
\end{aligned}
```
