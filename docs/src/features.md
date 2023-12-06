# [Model Features](@id features)

This section explains the main features in the optimization model inside [TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl).

## [Flexible Time Resolution](@id flex-time-res)

Tulipa can handle different time resolutions on the assets and the flows. Typically, the time resolution in an energy model is hourly like in the following figure:

![Hourly Time Resolution](./figs/variable-time-resolution-1.png)

However, we can have a variable time resolution for each asset and flow to reduce the optimization problem size and approximate the hourly representation. The following figure shows a definition aiming to have less variables to represent the system in the model:

![Variable Time Resolution](./figs/variable-time-resolution-2.png)

For this basic example, we can describe what the balance and capacity constraints in the model look like.

### Energy Balance Constraints

#### Storage Balance

```math
\begin{aligned}
& storage\_balance_{phs,1,1:6}: \\
& \qquad storage\_level_{phs,1,1:6} = 4 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),1,1:4} \\
& \qquad \quad + 2 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),1,5:6} - \frac{3}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),1,1:3} \\
& \qquad \quad - \frac{3}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),1,4:6}
\end{aligned}
```

#### Consumer Balance

```math
\begin{aligned}
& consumer\_balance_{demand,1,1:3}: \\
& \qquad 3 \cdot flow_{(balance,demand),1,1:3} = p^{peak\_demand}_{demand} \cdot \sum_{k=1}^{3} p^{profile}_{demand,1,k} \\
& consumer\_balance_{demand,1,4:6}: \\
& \qquad 3 \cdot flow_{(balance,demand),1,4:6} = p^{peak\_demand}_{demand} \cdot \sum_{k=4}^{6} p^{profile}_{demand,1,k} \\
\end{aligned}
```

#### Hub Balance

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

#### Conversion Balance

```math
\begin{aligned}
& conversion\_balance_{ccgt,1,1:6}: \\
& 6 \cdot p^{eff}_{(H2,ccgt)} \cdot flow_{(H2,ccgt),1,1:6} = \frac{1}{p^{eff}_{(ccgt,balance)}} \sum_{k=1}^{6} flow_{(ccgt,balance),1,k}  \\
\end{aligned}
```

### Capacity Constraints

#### Storage Capacity Constraints

The constraints for the outputs of the storage are (i.e., discharging capacity limit):

```math
\begin{aligned}
& max\_output\_flows\_limit_{phs,1,1:3}: \\
& \qquad flow_{(phs,balance),1,1:3} \leq p^{init\_capacity}_{phs} \\
& max\_output\_flows\_limit_{phs,1,4:6}: \\
& \qquad flow_{(phs,balance),1,4:6} \leq p^{init\_capacity}_{phs} \\
\end{aligned}
```

The constraints for the inputs of the storage are (i.e., charging capacity limit):

```math
\begin{aligned}
& max\_input\_flows\_limit_{phs,1,1:4}: \\
& \qquad flow_{(phs,balance),1,1:4} \leq p^{init\_capacity}_{phs} \\
& max\_input\_flows\_limit_{phs,1,5:6}: \\
& \qquad flow_{(phs,balance),1,5:6} \leq p^{init\_capacity}_{phs} \\
\end{aligned}
```

#### Conversion Capacity Constraints

```math
\begin{aligned}
& max\_output\_flows\_limit_{ccgt,1,1:1}: \\
& \qquad flow_{(ccgt,balance),1,1:1} \leq p^{init\_capacity}_{ccgt} \\
& max\_output\_flows\_limit_{ccgt,1,1:2}: \\
& \qquad flow_{(ccgt,balance),1,1:2} \leq p^{init\_capacity}_{ccgt} \\
& max\_output\_flows\_limit_{ccgt,1,1:3}: \\
& \qquad flow_{(ccgt,balance),1,1:3} \leq p^{init\_capacity}_{ccgt} \\
& max\_output\_flows\_limit_{ccgt,1,1:4}: \\
& \qquad flow_{(ccgt,balance),1,1:4} \leq p^{init\_capacity}_{ccgt} \\
& max\_output\_flows\_limit_{ccgt,1,1:5}: \\
& \qquad flow_{(ccgt,balance),1,1:5} \leq p^{init\_capacity}_{ccgt} \\
& max\_output\_flows\_limit_{ccgt,1,1:6}: \\
& \qquad flow_{(ccgt,balance),1,1:6} \leq p^{init\_capacity}_{ccgt} \\
\end{aligned}
```

#### Producers Capacity Constraints

For the wind producer asset we have two flows that outgoing, so:

```math
\begin{aligned}
& max\_output\_flows\_limit_{wind,1,1:4}: \\
& \qquad flow_{(wind,balance),1,1:4} + flow_{(wind,phs),1,1:4} \leq \frac{p^{init\_capacity}_{wind}}{4} \cdot \sum_{k=1}^{4} p^{profile}_{wind,1,k} \\
& max\_output\_flows\_limit_{wind,1,5:6}: \\
& \qquad flow_{(wind,balance),1,5:6} + flow_{(wind,phs),1,5:6} \leq \frac{p^{init\_capacity}_{wind}}{2} \cdot \sum_{k=5}^{6} p^{profile}_{wind,1,k} \\
\end{aligned}
```

For the hydrogen (H2) producer asset we have the following outgoing limit:

```math
\begin{aligned}
& max\_output\_flows\_limit_{H2,1,1:6}: \\
& \qquad flow_{(H2,ccgt),1,1:6} \leq p^{init\_capacity}_{wind} \cdot p^{profile}_{H2,1,1:6} \\
\end{aligned}
```

#### Transport Capacity Constraints

For the connection from the hub to the demand has associated a transmission capacity constraints like this:

```math
\begin{aligned}
& max\_transport\_flows\_limit_{(balance,demand),1,1:3}: \\
& \qquad flow_{(balance,demand),1,1:3} \leq p^{export\_capacity}_{(balance,demand)} \\
& max\_transport\_flows\_limit_{(balance,demand),1,4:6}: \\
& \qquad flow_{(balance,demand),1,4:6} \leq p^{export\_capacity}_{(balance,demand)} \\
\end{aligned}
```

```math
\begin{aligned}
& min\_transport\_flows\_limit_{(balance,demand),1,1:3}: \\
& \qquad flow_{(balance,demand),1,1:3} \geq - p^{import\_capacity}_{(balance,demand)} \\
& min\_transport\_flows\_limit_{(balance,demand),1,4:6}: \\
& \qquad flow_{(balance,demand),1,4:6} \geq - p^{import\_capacity}_{(balance,demand)} \\
\end{aligned}
```
