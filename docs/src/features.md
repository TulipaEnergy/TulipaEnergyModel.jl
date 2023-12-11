# [Model Features](@id features)

*TulipaEnergyModel.jl* incorporates two fundamental concepts that serve as the foundation of the optimization model:

- **Energy Assets**: representation of a physical asset that can produce, consume, store, balance, or convert energy. Some examples of what these assets can represent are:
  - Producer: wind turbine, solar panel
  - Consumer: electricity demand, heat demand
  - Storage: battery, pumped-hydro storage
  - Balancing Hub: electricity network that serves as a connection among other energy assets
  - Conversion: power plants, electrolizers
- **Flows**: representation of the connections among assets, e.g., pipelines, transmission lines, or just simple the energy production that goes from one asset to another.

This section explains the main features in the optimization model inside the model based on these definitions.

## [Flexible Connexion of Energy Assets](@id flex-asset-connexion)

The representation of the energy system in *TulipaEnergyModel.jl* is based on [Graph Theory](https://www.britannica.com/topic/graph-theory), which deals with connection amongst vertices by edges. This representation provides a more flexible framework to model *energy assets* in the system as *vertices* and *flows* between energy assets as *edges*. In addition, it poses some advantages from the modelling perspective. For instance, connecting assets directly to each other without having a node between them allows for a reduction of the number of variables and constraints to represent different configurations (e.g., co-location of energy storage and renewable units to model a hybrid operation).

## [Flexible Time Resolution](@id flex-time-res)

One of the core features of *TulipaEnergyModel.jl* is that it can handle different time resolutions on the assets and the flows. Typically, the time resolution in an energy model is hourly like in the following figure:

![Hourly Time Resolution](./figs/variable-time-resolution-1.png)

It is possible to have different time resolutions for each asset and flow to simplify the optimization problem and approximate hourly representation. This feature is particularly useful for large-scale energy systems that involve different sectors, as detailed granularity is not always necessary due to the unique temporal dynamics of each sector. For instance, we can use hourly resolution for the electricity sector and six-hour resolution for the hydrogen sector. We can couple multiple sectors, each with its temporal resolution. The following figure illustrates how we can have fewer variables to represent the system in the model. Please note that the values presented here are just for illustrative purposes and do not represent a realistic case.

![Variable Time Resolution](./figs/variable-time-resolution-2.png)

Where:

- The hydrogen producer (`H2`) is in a six-hour resolution represented by the range `1:6`, meaning that the balance of the hydrogen produced is for every six hours.
- The flow from the hydrogen producer to the ccgt power plant (`H2,ccgt`) is also in a six-hour resolution `1:6`.
- The flow from the ccgt power plant to the balance hub (`ccgt,balance`) is in an hourly resolution `[1,2,3,4,5,6]`.
- The `ccgt` is a conversion plant that takes hydrogen to produce electricity. Since both sectors are in different time resolutions. The energy balance in the conversion asset is done in the lowest resolution connecting to the asset. In this case, the energy balance in the `ccgt` is done every six hours, i.e., in the range `1:6`.
- The `wind` producer has an hourly profile of electricity production, so the resolution of the asset is still hourly.
- The `wind` producer output has two connections, one to the `balance` hub and the other to the pumped-hydro storage (`phs`) with different resolutions:
  - The flow from the wind producer to the phs storage (`wind,phs`) has a uniform resolution of two blocks from hour 1 to 3 (i.e., `1:3`) and from hour 4 to 6 (i.e., `4:6`).
  - The flow from the wind producer to the balance hub (`wind,balance`) has a variable resolution of two blocks, too, but from hour 1 to 2 (i.e., `1:2`) and from hour 3 to 6 (i.e., `3:6`).
- The `phs` is in a six-hour resolution represented by the range `1:6`, meaning the storage balance is determined every six hours.
- The flow from the phs to the balance (`phs,balance`) represents the discharge of the `phs`. This flow has a variable resolution of two blocks from hour 1 to 4 (i.e., `1:4`) and from hour 5 to 6 (i.e., `5:6`), which differs from the one defined for the charging flow from the `wind` asset.
- The `demand` consumption has hourly input data with one connection to the `balance` hub:
  - The flow from the balance hub to the demand (`balance,demand`) has a uniform resolution of three hours; therefore, it has two blocks, one from hour 1 to 3 (i.e., `1:3`) and the other from hour 4 to 6 (i.e., `4:6`).
- The `balance` hub integrates all the different assets with their different resolutions. The highest resolution of all connections determines the balance equation for this asset. Therefore, the resulting resolution is into two blocks, one from hour 1 to 4 (i.e., `1:4`) and the other from hour 5 to 6 (i.e., `5:6`).

> **Note**
> This example demonstrates that different time resolutions can be assigned to each asset and flow in the model. Additionally, the resolutions do not need to be uniform and can vary throughout the horizon.

The complete input data for this example can be found in the following [link](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Variable%20Resolution).

For this basic example, we can describe what the balance and capacity constraints in the model look like. For the sake of simplicity, the representative period index is dropped from the equations and there is no investment variables in the equations.

### Energy Balance Constraints

All balancing equations are defined in the lowest resolution to reduce the number of constraints in the optimization model.

#### Storage Balance

Since the storage asset has a resolution of six hours and both the charging and discharging flows are higher than this, the storage balance constraint is defined in the exact resolution for the storage asset (i.e., the one with the lowest resolution). The charging and discharging flows are multiply by their durations to account for the energy in the range `1:6`.

```math
\begin{aligned}
& storage\_balance_{phs,1:6}: \\
& \qquad storage\_level_{phs,1:6} = 3 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),1:3} \\
& \qquad \quad + 3 \cdot p^{eff}_{(wind,phs)} \cdot flow_{(wind,phs),4:6} - \frac{4}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),1:4} \\
& \qquad \quad - \frac{2}{p^{eff}_{(phs,balance)}} \cdot flow_{(phs,balance),5:6}
\end{aligned}
```

#### Consumer Balance

The demand input data is defined hourly; however, the flows coming from the balancing hub are defined every three hours. Therefore, the flows impose the lowest resolution on this occasion, and the balance at the demand is done every three hours. The input demand is aggregated for each time block. As in the storage balance, the flows are multiplied by their duration.

```math
\begin{aligned}
& consumer\_balance_{demand,1:3}: \\
& \qquad 3 \cdot flow_{(balance,demand),1:3} = p^{peak\_demand}_{demand} \cdot \sum_{k=1}^{3} p^{profile}_{demand,k} \\
& consumer\_balance_{demand,4:6}: \\
& \qquad 3 \cdot flow_{(balance,demand),4:6} = p^{peak\_demand}_{demand} \cdot \sum_{k=4}^{6} p^{profile}_{demand,k} \\
\end{aligned}
```

#### Hub Balance

The hub balance is quite interesting because it integrates several flow resolutions. The lowest resolution of all assets in the whole horizon implies that the hub balance must be imposed for two blocks, `1:4` and `5:6`. The balance must account for each flow variable's duration in each block.

```math
\begin{aligned}
& hub\_balance_{balance,1:4}: \\
& \qquad \sum_{k=1}^{4} flow_{(ccgt,balance),k} + 2 \cdot flow_{(wind,balance),1:2} \\
& \qquad + 2 \cdot flow_{(wind,balance),3:6} + 4 \cdot flow_{(phs,balance),1:4} \\
& \qquad - 3 \cdot flow_{(balance,demand),1:3} - 1 \cdot flow_{(balance,demand),4:6} = 0 \\
& hub\_balance_{balance,5:6}: \\
& \qquad \sum_{k=5}^{6} flow_{(ccgt,balance),k} + 2 \cdot flow_{(wind,balance),3:6} \\
& \qquad + 2 \cdot flow_{(phs,balance),5:6} - 2 \cdot flow_{(balance,demand),4:6} = 0 \\
\end{aligned}
```

#### Conversion Balance

The flows connected to the CCGT conversion unit have different resolutions, too. In this case, the hydrogen imposes the lowest resolution, therefore the energy balance in this asset is also for every six hours.

```math
\begin{aligned}
& conversion\_balance_{ccgt,1:6}: \\
& 6 \cdot p^{eff}_{(H2,ccgt)} \cdot flow_{(H2,ccgt),1:6} = \frac{1}{p^{eff}_{(ccgt,balance)}} \sum_{k=1}^{6} flow_{(ccgt,balance),k}  \\
\end{aligned}
```

### Capacity Constraints

All capacity constraints are defined in the highest resolution to guarantee that the flows are below the limits of each asset capacity.

#### Storage Capacity Constraints

Since the storage unit only has one input and output, the capacity limit constraints are in the exact resolution as the individual flows. Therefore, The constraints for the outputs of the storage are (i.e., discharging capacity limit):

```math
\begin{aligned}
& max\_output\_flows\_limit_{phs,1:3}: \\
& \qquad flow_{(phs,balance),1:3} \leq p^{init\_capacity}_{phs} \\
& max\_output\_flows\_limit_{phs,4:6}: \\
& \qquad flow_{(phs,balance),4:6} \leq p^{init\_capacity}_{phs} \\
\end{aligned}
```

And, the constraints for the inputs of the storage are (i.e., charging capacity limit):

```math
\begin{aligned}
& max\_input\_flows\_limit_{phs,1:4}: \\
& \qquad flow_{(phs,balance),1:4} \leq p^{init\_capacity}_{phs} \\
& max\_input\_flows\_limit_{phs,5:6}: \\
& \qquad flow_{(phs,balance),5:6} \leq p^{init\_capacity}_{phs} \\
\end{aligned}
```

#### Conversion Capacity Constraints

Similarly, each outflow is limited to the `ccgt` capacity for the conversion unit.

```math
\begin{aligned}
& max\_output\_flows\_limit_{ccgt,k}: \\
& \qquad flow_{(ccgt,balance),k} \leq p^{init\_capacity}_{ccgt} \quad \forall k \in [1,6] \\
\end{aligned}
```

#### Producers Capacity Constraints

The `wind` producer asset is interesting because the output flows are in different resolutions. Therefore, the highest resolution rule imposes that we have three constraints as follows:

```math
\begin{aligned}
& max\_output\_flows\_limit_{wind,1:2}: \\
& \qquad flow_{(wind,balance),1:2} + flow_{(wind,phs),1:3} \leq \frac{p^{init\_capacity}_{wind}}{2} \cdot \sum_{k=1}^{2} p^{profile}_{wind,k} \\
& max\_output\_flows\_limit_{wind,3}: \\
& \qquad flow_{(wind,balance),3:6} + flow_{(wind,phs),1:3} \leq p^{init\_capacity}_{wind} \cdot p^{profile}_{wind,3} \\
& max\_output\_flows\_limit_{wind,4:6}: \\
& \qquad flow_{(wind,balance),3:6} + flow_{(wind,phs),4:6} \leq \frac{p^{init\_capacity}_{wind}}{2} \cdot \sum_{k=5}^{6} p^{profile}_{wind,k} \\
\end{aligned}
```

The hydrogen (H2) producer capacity limit is straightforward since both the asset and the flow definition are in the exact time resolution:

```math
\begin{aligned}
& max\_output\_flows\_limit_{H2,1:6}: \\
& \qquad flow_{(H2,ccgt),1:6} \leq p^{init\_capacity}_{wind} \cdot p^{profile}_{H2,1:6} \\
\end{aligned}
```

#### Transport Capacity Constraints

For the connection from the hub to the demand there are associated transmission capacity constraints, which are in the same resolution as the flow:

```math
\begin{aligned}
& max\_transport\_flows\_limit_{(balance,demand),1:3}: \\
& \qquad flow_{(balance,demand),1:3} \leq p^{export\_capacity}_{(balance,demand)} \\
& max\_transport\_flows\_limit_{(balance,demand),4:6}: \\
& \qquad flow_{(balance,demand),4:6} \leq p^{export\_capacity}_{(balance,demand)} \\
\end{aligned}
```

```math
\begin{aligned}
& min\_transport\_flows\_limit_{(balance,demand),1:3}: \\
& \qquad flow_{(balance,demand),1:3} \geq - p^{import\_capacity}_{(balance,demand)} \\
& min\_transport\_flows\_limit_{(balance,demand),4:6}: \\
& \qquad flow_{(balance,demand),4:6} \geq - p^{import\_capacity}_{(balance,demand)} \\
\end{aligned}
```
