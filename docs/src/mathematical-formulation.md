# [Mathematical Formulation](@id math-formulation)

This section shows the mathematical formulation of the model, assuming that the temporal definition of time steps is the same for all the elements in the model.\
The complete mathematical formulation considering variable temporal resolutions is also freely available in the [preprint](https://arxiv.org/abs/2309.07711). In addition, the feature section has an example of how the model handles the [`flexible time resolution`](@ref flex-time-res).

## [Sets](@id math-sets)

| Name                         | Description                                         | Elements                  | Superset                                                   | Notes                                                                      |
| ---------------------------- | --------------------------------------------------- | ------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------- |
| $\mathcal{A}$                | Energy assets                                       | $a \in \mathcal{A}$       |                                                            |                                                                            |
| $\mathcal{A}^{\text{c}}$     | Consumer energy assets                              |                           | $\mathcal{A}^{\text{c}}  \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{A}^{\text{p}}$     | Producer energy assets                              |                           | $\mathcal{A}^{\text{p}}  \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{A}^{\text{s}}$     | Storage energy assets                               |                           | $\mathcal{A}^{\text{s}}  \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{A}^{\text{ss}}$    | Seaonal Storage energy assets                       |                           | $\mathcal{A}^{\text{ss}} \subseteq \mathcal{A}^{\text{s}}$ |                                                                            |
| $\mathcal{A}^{\text{h}}$     | Hub energy assets (e.g., transshipment)             |                           | $\mathcal{A}^{\text{h}}  \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{A}^{\text{cv}}$    | Conversion energy assets                            |                           | $\mathcal{A}^{\text{cv}} \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{A}^{\text{i}}$     | Energy assets with investment method                |                           | $\mathcal{A}^{\text{i}}  \subseteq \mathcal{A}$            |                                                                            |
| $\mathcal{F}$                | Flow connections between two assets                 | $f \in \mathcal{F}$       |                                                            |                                                                            |
| $\mathcal{F}^{\text{t}}$     | Transport flow between two assets                   |                           | $\mathcal{F}^{\text{t}} \subseteq \mathcal{F}$             |                                                                            |
| $\mathcal{F}^{\text{ti}}$    | Transport flow with investment method               |                           | $\mathcal{F}^{\text{ti}} \subseteq \mathcal{F}^{\text{t}}$ |                                                                            |
| $\mathcal{F}^{\text{in}}_a$  | Set of flows going into asset $a$                   |                           | $\mathcal{F}^{\text{in}}_a  \subseteq \mathcal{F}$         |                                                                            |
| $\mathcal{F}^{\text{out}}_a$ | Set of flows going out of asset $a$                 |                           | $\mathcal{F}^{\text{out}}_a \subseteq \mathcal{F}$         |                                                                            |
| $\mathcal{P}$                | Periods in the timeframe                            | $p \in \mathcal{P}$       | $\mathcal{P} \subset \mathbb{N}$                           |                                                                            |
| $\mathcal{K}$                | Representative periods (rp)                         | $k \in \mathcal{K}$       | $\mathcal{K} \subset \mathbb{N}$                           | $\mathcal{K}$ does not have to be a subset of $\mathcal{P}$                |
| $\mathcal{B}_{k}$            | Timesteps blocks within a representative period $k$ | $b_{k} \in \mathcal{B}_k$ |                                                            | $\mathcal{B}_k$ is a partition of timesteps in a representative period $k$ |

NOTE: Asset types are mutually exclusive.

## [Parameters](@id math-parameters)

| Name                                        | Domain           | Domains of Indices                                                      | Description                                                                                                    | Units          |
| ------------------------------------------- | ---------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------- |
| $p^{\text{investment cost}}_{a}$            | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                     | Investment cost of a unit of asset $a$                                                                         | [kEUR/MW/year] |
| $p^{\text{investment limit}}_{a}$           | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                     | Investment limit of a unit of asset $a$                                                                        | [MW]           |
| $p^{\text{unit capacity}}_{a}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                     | Capacity per unit of asset $a$                                                                                 | [MW]           |
| $p^{\text{peak demand}}_{a}$                | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{c}}$                                          | Peak demand of consumer asset $a$                                                                              | [MW]           |
| $p^{\text{init capacity}}_{a}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                     | Initial capacity of asset $a$                                                                                  | [MW]           |
| $p^{\text{variable cost}}_{f}$              | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$                                                     | Variable cost of flow $f$                                                                                      | [kEUR/MWh]     |
| $p^{\text{eff}}_f$                          | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$                                                     | Efficiency of flow $f$                                                                                         | [p.u.]         |
| $p^{\text{investment cost}}_{f}$            | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                          | Investment cost of transport flow $f$                                                                          | [kEUR/MW/year] |
| $p^{\text{investment limit}}_{f}$           | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                          | Investment limit of a unit of flow $f$                                                                         | [MW]           |
| $p^{\text{capacity increment}}_{f}$         | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                          | Capacity increment for investments of transport flow $f$ (both exports and imports)                            | [MW]           |
| $p^{\text{init export capacity}}_{f}$       | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                          | Initial export capacity of transport flow $f$                                                                  | [MW]           |
| $p^{\text{init import capacity}}_{f}$       | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                          | Initial import capacity of transport flow $f$                                                                  | [MW]           |
| $p^{\text{rp weight}}_{k}$                  | $\mathbb{R}_{+}$ | $k \in \mathcal{K}$                                                     | Weight of representative period $k$                                                                            | [-]            |
| $p^{\text{availability profile}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}, k \in \mathcal{K}, b_k \in \mathcal{B_k}$           | Availability profile of asset $a$ in the representative period $k$ and timestep block $b_k$                    | [p.u.]         |
| $p^{\text{availability profile}}_{f,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{F}, k \in \mathcal{K}, b_k \in \mathcal{B_k}$           | Availability profile of flow $f$ in the representative period $k$ and timestep block $b_k$                     | [p.u.]         |
| $p^{\text{demand profile}}_{a,k,b_k}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{c}}},k \in \mathcal{K}, b_k \in \mathcal{B_k}$ | Demand profile of consumer asset $a$ in the representative period $k$ and timestep block $b_k$                 | [p.u.]         |
| $p^{\text{inflows}}_{a,k,b_k}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}},k \in \mathcal{K}, b_k \in \mathcal{B_k}$ | Inflows of storage asset $a$ in the representative period $k$ and timestep block $b_k$                         | [MWh]          |
| $p^{\text{max intra level}}_{a,k,b_k}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}},k \in \mathcal{K}, b_k \in \mathcal{B_k}$ | Maximum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]         |
| $p^{\text{min intra level}}_{a,k,b_k}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}},k \in \mathcal{K}, b_k \in \mathcal{B_k}$ | Minimum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]         |
| $p^{\text{max inter level}}_{a,p}$          | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}},p \in \mathcal{P}$                        | Maximum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]         |
| $p^{\text{min inter level}}_{a,p}$          | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}},p \in \mathcal{P}$                        | Minimum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]         |
| $p^{\text{energy to power ratio}}_a$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                          | Energy to power ratio of storage asset $a$                                                                     | [h]            |
| $p^{\text{init storage capacity}}_{a}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                          | Initial storage capacity of storage asset $a$                                                                  | [MWh]          |
| $p^{\text{init storage level}}_{a}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                          | Initial storage level of storage asset $a$                                                                     | [MWh]          |
| $p^{\text{map}}_{p,k}$                      | $\mathbb{R}_{+}$ | $p \in \mathcal{P}, k \in \mathcal{K}$                                  | Map with the weight of representative period $k$ in period $p$                                                 | [-]            |

## [Variables](@id math-variables)

| Name                         | Domain           | Domains of Indices                                                       | Description                                                                                                                     | Units   |
| ---------------------------- | ---------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- | ------- |
| $v^{\text{flow}}_{f,k,b_k}$  | $\mathbb{R}$     | $f \in \mathcal{F}, k \in \mathcal{K}, b_k \in \mathcal{B_k}$            | Flow $f$ between two assets in representative period $k$ and timestep block $b_k$                                               | [MW]    |
| $v^{\text{investment}}_{a}$  | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}$                                           | Number of invested units of asset $a$                                                                                           | [units] |
| $v^{\text{investment}}_{f}$  | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{i}}$                                           | Number of invested capacity increments of flow $f$                                                                              | [units] |
| $s^{\text{intra}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}, k \in \mathcal{K}, b_k \in \mathcal{B_k}$ | Intra storage level (within a representative period) for storage asset $a$, representative period $k$, and timestep block $b_k$ | [MWh]   |
| $s^{\text{inter}}_{a,p}$     | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}, p \in \mathcal{P}$                        | Inter storage level (between representative periods) for storage asset $a$ and period $p$                                       | [MWh]   |

## [Objective Function](@id math-objective-function)

Objective function:

```math
\begin{aligned}
\text{{minimize}} \quad & assets\_investment\_cost + flows\_investment\_cost \\
                        & + flows\_variable\_cost
\end{aligned}
```

Where:

```math
\begin{aligned}
assets\_investment\_cost &= \sum_{a \in \mathcal{A}^{\text{i}}} p^{\text{investment cost}}_{a} \cdot p^{\text{unit capacity}}_{a} \cdot v^{\text{investment}}_{a} \\
flows\_investment\_cost &= \sum_{f \in \mathcal{F}^{\text{ti}}} p^{\text{investment cost}}_{f} \cdot p^{\text{capacity increment}}_{f} \cdot v^{\text{investment}}_{f} \\
flows\_variable\_cost &= \sum_{f \in \mathcal{F}} \sum_{k \in \mathcal{K}} \sum_{b_k \in \mathcal{B_k}} p^{\text{rp weight}}_{k} \cdot p^{\text{variable cost}}_{f} \cdot v^{\text{flow}}_{f,k,b_k}
\end{aligned}
```

## [Constraints](@id math-constraints)

### Capacity Constraints

#### Maximum Output Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{unit capacity}}_{a} \cdot v^{\text{investment}}_{a} \right)  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{s}} \cup \mathcal{A}^{\text{p}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Maximum Input Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{unit capacity}}_{a} \cdot v^{\text{investment}}_{a} \right)  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Lower Limit for Flows that are not Transport Assets

```math
v^{\text{flow}}_{f,k,b_k} \geq 0 \quad \forall f \notin \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K}, \forall b_k \in \mathcal{B_k}
```

### Constraints for Energy Consumer Assets

#### Balance Constraint for Consumers

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} = p^{\text{demand profile}}_{a,k,b_k} \cdot p^{\text{peak demand}}_{a} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{c}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Energy Storage Assets

Regarding energy storage assets, there are two constraint types: intra-temporal and inter-temporal. Intra-temporal constraints are limitations within the representative periods, while inter-temporal constraints are restrictions between the representative periods. Inter-temporal constraints allow us to model seasonal storage by mapping the representative periods $\mathcal{K}$ to the periods $\mathcal{P}$ in the model's timeframe. For more information on this topic, refer to Tejada-Arango et al. (2018) and Tejada-Arango et al. (2019) in the [reference](@ref math-references) section.

#### Intra-temporal Constraint for Storage Balance

```math
\begin{aligned}
s^{\text{intra}}_{a,k,b_k} = s^{\text{intra}}_{a,k,b_k-1}  + p^{\text{inflows}}_{a,k,b_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot v^{\text{flow}}_{f,k,b_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Intra-temporal Constraint for Maximum Storage Level Limit

```math
s^{\text{intra}}_{a,k,b_k} \leq p^{\text{max intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{investment}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Constraint for Minimum Storage Level Limit

```math
s^{\text{intra}}_{a,k,b_k} \geq p^{\text{min intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{investment}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Constraint for Cycling Constraint

If parameter $p^{\text{init storage level}}_{a}$ is defined, the intra-storage level of the last timestep block ($b^{\text{last}}_k$) in each representative period must be greater than this initial value.

```math
s^{\text{intra}}_{a,k,B_k} \geq p^{\text{init storage level}}_{a} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K}
```

#### Inter-temporal Constraint for Storage Balance

This constraint allows us to consider the storage's seasonality throughout the model's timeframe (e.g., a year). The parameter $p^{\text{map}}_{p,k}$ determines how much of the representative period $k$ is in the period $p$, and you can use a clustering technique to calculate it. For _TulipaEnergyModel.jl_, we recommend using [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl) to compute the clusters for the representative periods and their map.

For the sake of simplicity, we show the constraint assuming that we are calculating the inter-storage level between two consecutive periods $p$; however, _TulipaEnergyModel.jl_ can handle more extensive period block definition through the XXX definition in the model.

```math
\begin{aligned}
s^{\text{inter}}_{a,p} = & s^{\text{inter}}_{a,p-1} + \sum_{\rho = p-1}^{p} \sum_{k \in \mathcal{K}} p^{\text{map}}_{\rho,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{\rho = p-1}^{p} \sum_{k \in \mathcal{K}} p^{\text{map}}_{\rho,k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{\rho = p-1}^{p} \sum_{k \in \mathcal{K}} p^{\text{map}}_{\rho,k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
\end{aligned}
```

#### Inter-temporal Constraint for Maximum Storage Level Limit

```math
s^{\text{inter}}_{a,p} \leq p^{\text{max inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{investment}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Constraint for Minimum Storage Level Limit

```math
s^{\text{inter}}_{a,p} \geq p^{\text{min inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{investment}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Constraint for Cycling Constraint

If parameter $p^{\text{init storage level}}_{a}$ is defined, the inter-storage level of the last timestep block ($p^{\text{last}}$) in each representative period must be greater than this initial value.

```math
s^{\text{inter}}_{a,p^{\text{last}}} \geq p^{\text{init storage level}}_{a} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{ss}}
```

### Constraints for Energy Hub Assets

#### Balance Constraint for Hubs

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} = \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{h}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Energy Conversion Assets

#### Balance Constraint for Conversion Assets

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b_k} = \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{v^{\text{flow}}_{f,k,b_k}}{p^{\text{eff}}_f} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{cv}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Transport Assets

#### Maximum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init export capacity}}_{f} + p^{\text{capacity increment}}_{f} \cdot v^{\text{investment}}_{f} \right)  \quad
\\ \\ \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Minimum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k,b_k} \geq - p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init import capacity}}_{f} + p^{\text{capacity increment}}_{f} \cdot v^{\text{investment}}_{f} \right)  \quad
\\ \\ \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Investments

#### Maximum Investment Limit for Assets

```math
v^{\text{investment}}_{a} \leq \frac{p^{\text{investment limit}}_{a}}{p^{\text{unit capacity}}_{a}} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{i}}
```

#### Maximum Investment Limit for Flows

```math
v^{\text{investment}}_{f} \leq \frac{p^{\text{investment limit}}_{f}}{p^{\text{capacity increment}}_{f}} \quad
\\ \\ \forall f \in \mathcal{F}^{\text{ti}}
```

## [References](@id math-references)

Tejada-Arango, D.A., Domeshek, M., Wogrin, S., Centeno, E., 2018. Enhanced representative days and system states modeling for energy storage investment analysis. IEEE Transactions on Power Systems 33, 6534–6544. doi:10.1109/TPWRS.2018.2819578.

Tejada-Arango, D.A., Wogrin, S., Siddiqui, A.S., Centeno, E., 2019. Opportunity cost including short-term energy storage in hydrothermal dispatch models using a linked representative periods approach. Energy 188, 116079. doi:10.1016/j.energy.2019.116079.
