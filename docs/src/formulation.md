# [Mathematical Formulation](@id formulation)

This section shows the mathematical formulation of _TulipaEnergyModel.jl_, assuming that the temporal definition of timesteps is the same for all the elements in the model.\
The complete mathematical formulation, including variable temporal resolutions, is also freely available in the [preprint](https://arxiv.org/abs/2309.07711). In addition, the [concepts section](@ref seasonal-storage) has an example of how the model handles the [`flexible time resolution`](@ref flex-time-res).

## [Sets](@id math-sets)

### Sets for Assets

| Name                      | Description                             | Elements            | Superset                                        | Notes                                                                                                  |
| ------------------------- | --------------------------------------- | ------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| $\mathcal{A}$             | Energy assets                           | $a \in \mathcal{A}$ |                                                 | The Energy asset types (i.e., consumer, producer, storage, hub, and conversion) are mutually exclusive |
| $\mathcal{A}^{\text{c}}$  | Consumer energy assets                  |                     | $\mathcal{A}^{\text{c}}  \subseteq \mathcal{A}$ |                                                                                                        |
| $\mathcal{A}^{\text{p}}$  | Producer energy assets                  |                     | $\mathcal{A}^{\text{p}}  \subseteq \mathcal{A}$ |                                                                                                        |
| $\mathcal{A}^{\text{s}}$  | Storage energy assets                   |                     | $\mathcal{A}^{\text{s}}  \subseteq \mathcal{A}$ |                                                                                                        |
| $\mathcal{A}^{\text{h}}$  | Hub energy assets (e.g., transshipment) |                     | $\mathcal{A}^{\text{h}}  \subseteq \mathcal{A}$ |                                                                                                        |
| $\mathcal{A}^{\text{cv}}$ | Conversion energy assets                |                     | $\mathcal{A}^{\text{cv}} \subseteq \mathcal{A}$ |                                                                                                        |

In addition, the following asset sets represent methods for incorporating additional variables and constraints in the model.

| Name                      | Description                                | Elements | Superset                                                   | Notes |
| ------------------------- | ------------------------------------------ | -------- | ---------------------------------------------------------- | ----- |
| $\mathcal{A}^{\text{i}}$  | Energy assets with investment method       |          | $\mathcal{A}^{\text{i}}  \subseteq \mathcal{A}$            |       |
| $\mathcal{A}^{\text{ss}}$ | Storage energy assets with seasonal method |          | $\mathcal{A}^{\text{ss}} \subseteq \mathcal{A}^{\text{s}}$ |       |

### Sets for Flows

| Name                         | Description                         | Elements            | Superset                                           | Notes |
| ---------------------------- | ----------------------------------- | ------------------- | -------------------------------------------------- | ----- |
| $\mathcal{F}$                | Flow connections between two assets | $f \in \mathcal{F}$ |                                                    |       |
| $\mathcal{F}^{\text{in}}_a$  | Set of flows going into asset $a$   |                     | $\mathcal{F}^{\text{in}}_a  \subseteq \mathcal{F}$ |       |
| $\mathcal{F}^{\text{out}}_a$ | Set of flows going out of asset $a$ |                     | $\mathcal{F}^{\text{out}}_a \subseteq \mathcal{F}$ |       |

In addition, the following flow sets represent methods for incorporating additional variables and constraints in the model.

| Name                      | Description                                     | Elements | Superset                                                   | Notes |
| ------------------------- | ----------------------------------------------- | -------- | ---------------------------------------------------------- | ----- |
| $\mathcal{F}^{\text{t}}$  | Flow between two assets with a transport method |          | $\mathcal{F}^{\text{t}} \subseteq \mathcal{F}$             |       |
| $\mathcal{F}^{\text{ti}}$ | Transport flow with investment method           |          | $\mathcal{F}^{\text{ti}} \subseteq \mathcal{F}^{\text{t}}$ |       |

### Sets for Temporal Structures

| Name              | Description                                         | Elements                  | Superset                         | Notes                                                                      |
| ----------------- | --------------------------------------------------- | ------------------------- | -------------------------------- | -------------------------------------------------------------------------- |
| $\mathcal{P}$     | Periods in the timeframe                            | $p \in \mathcal{P}$       | $\mathcal{P} \subset \mathbb{N}$ |                                                                            |
| $\mathcal{K}$     | Representative periods (rp)                         | $k \in \mathcal{K}$       | $\mathcal{K} \subset \mathbb{N}$ | $\mathcal{K}$ does not have to be a subset of $\mathcal{P}$                |
| $\mathcal{B}_{k}$ | Timesteps blocks within a representative period $k$ | $b_{k} \in \mathcal{B}_k$ |                                  | $\mathcal{B}_k$ is a partition of timesteps in a representative period $k$ |

## [Parameters](@id math-parameters)

### Parameter for Assets

| Name                                        | Domain           | Domains of Indices                                                           | Description                                                                                                    | Units          |
| ------------------------------------------- | ---------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------- |
| $p^{\text{inv cost}}_{a}$                   | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                          | Investment cost of a unit of asset $a$                                                                         | [kEUR/MW/year] |
| $p^{\text{inv limit}}_{a}$                  | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                          | Investment potential of asset $a$                                                                              | [MW]           |
| $p^{\text{capacity}}_{a}$                   | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                          | Capacity per unit of asset $a$                                                                                 | [MW]           |
| $p^{\text{init capacity}}_{a}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$                                                          | Initial capacity of asset $a$                                                                                  | [MW]           |
| $p^{\text{peak demand}}_{a}$                | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{c}}$                                               | Peak demand of consumer asset $a$                                                                              | [MW]           |
| $p^{\text{energy to power ratio}}_a$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                               | Energy to power ratio of storage asset $a$                                                                     | [h]            |
| $p^{\text{init storage capacity}}_{a}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                               | Initial storage capacity of storage asset $a$                                                                  | [MWh]          |
| $p^{\text{init storage level}}_{a}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                               | Initial storage level of storage asset $a$                                                                     | [MWh]          |
| $p^{\text{availability profile}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$            | Availability profile of asset $a$ in the representative period $k$ and timestep block $b_k$                    | [p.u.]         |
| $p^{\text{demand profile}}_{a,k,b_k}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{c}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Demand profile of consumer asset $a$ in the representative period $k$ and timestep block $b_k$                 | [p.u.]         |
| $p^{\text{inflows}}_{a,k,b_k}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Inflows of storage asset $a$ in the representative period $k$ and timestep block $b_k$                         | [MWh]          |
| $p^{\text{max intra level}}_{a,k,b_k}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Maximum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]         |
| $p^{\text{min intra level}}_{a,k,b_k}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Minimum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]         |
| $p^{\text{max inter level}}_{a,p}$          | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $p \in \mathcal{P}$                          | Maximum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]         |
| $p^{\text{min inter level}}_{a,p}$          | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $p \in \mathcal{P}$                          | Minimum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]         |

### Parameter for Flows

| Name                                        | Domain           | Domains of Indices                                                | Description                                                                                | Units          |
| ------------------------------------------- | ---------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------------- |
| $p^{\text{variable cost}}_{f}$              | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$                                               | Variable cost of flow $f$                                                                  | [kEUR/MWh]     |
| $p^{\text{eff}}_f$                          | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$                                               | Efficiency of flow $f$                                                                     | [p.u.]         |
| $p^{\text{inv cost}}_{f}$                   | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                    | Investment cost of transport flow $f$                                                      | [kEUR/MW/year] |
| $p^{\text{inv limit}}_{f}$                  | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                    | Investment potential of flow $f$                                                           | [MW]           |
| $p^{\text{capacity}}_{f}$                   | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                    | Capacity per unit of investment of transport flow $f$ (both exports and imports)           | [MW]           |
| $p^{\text{init export capacity}}_{f}$       | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                    | Initial export capacity of transport flow $f$                                              | [MW]           |
| $p^{\text{init import capacity}}_{f}$       | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                    | Initial import capacity of transport flow $f$                                              | [MW]           |
| $p^{\text{availability profile}}_{f,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{F}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Availability profile of flow $f$ in the representative period $k$ and timestep block $b_k$ | [p.u.]         |

### Parameter for Temporal Structures

| Name                       | Domain           | Domains of Indices                       | Description                                                    | Units |
| -------------------------- | ---------------- | ---------------------------------------- | -------------------------------------------------------------- | ----- |
| $p^{\text{rp weight}}_{k}$ | $\mathbb{R}_{+}$ | $k \in \mathcal{K}$                      | Weight of representative period $k$                            | [-]   |
| $p^{\text{map}}_{p,k}$     | $\mathbb{R}_{+}$ | $p \in \mathcal{P}$, $k \in \mathcal{K}$ | Map with the weight of representative period $k$ in period $p$ | [-]   |

## [Variables](@id math-variables)

| Name                                 | Domain           | Domains of Indices                                                                                             | Description                                                                                                                     | Units   |
| ------------------------------------ | ---------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------- |
| $v^{\text{flow}}_{f,k,b_k}$          | $\mathbb{R}$     | $f \in \mathcal{F}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$                                              | Flow $f$ between two assets in representative period $k$ and timestep block $b_k$                                               | [MW]    |
| $v^{\text{inv}}_{a}$                 | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}$                                                                                 | Number of invested units of asset $a$                                                                                           | [units] |
| $v^{\text{inv}}_{f}$                 | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{ti}}$                                                                                | Number of invested units of capacity increment of transport flow $f$                                                            | [units] |
| $v^{\text{intra-storage}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Intra storage level (within a representative period) for storage asset $a$, representative period $k$, and timestep block $b_k$ | [MWh]   |
| $v^{\text{inter-storage}}_{a,p}$     | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}$, $p \in \mathcal{P}$                                                           | Inter storage level (between representative periods) for storage asset $a$ and period $p$                                       | [MWh]   |

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
assets\_investment\_cost &= \sum_{a \in \mathcal{A}^{\text{i}}} p^{\text{inv cost}}_{a} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \\
flows\_investment\_cost &= \sum_{f \in \mathcal{F}^{\text{ti}}} p^{\text{inv cost}}_{f} \cdot p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \\
flows\_variable\_cost &= \sum_{f \in \mathcal{F}} \sum_{k \in \mathcal{K}} \sum_{b_k \in \mathcal{B_k}} p^{\text{rp weight}}_{k} \cdot p^{\text{variable cost}}_{f} \cdot v^{\text{flow}}_{f,k,b_k}
\end{aligned}
```

## [Constraints](@id math-constraints)

### Capacity Constraints

#### Maximum Output Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{s}} \cup \mathcal{A}^{\text{p}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Maximum Input Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
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

There are two types of constraints for energy storage assets: intra-temporal and inter-temporal. Intra-temporal constraints impose limits within the representative periods, while inter-temporal constraints restrict storage between representative periods. Inter-temporal constraints allow us to model seasonal storage by mapping the representative periods $\mathcal{K}$ to the periods $\mathcal{P}$ in the model's timeframe. For more information on this topic, refer to the [concepts section](@ref seasonal-storage) or [Tejada-Arango et al. (2018)](https://ieeexplore.ieee.org/document/8334256) and [Tejada-Arango et al. (2019)](https://www.sciencedirect.com/science/article/pii/S0360544219317748).

#### [Intra-temporal Constraint for Storage Balance](@id intra-storage-balance)

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b_k} = v^{\text{intra-storage}}_{a,k,b_k-1}  + p^{\text{inflows}}_{a,k,b_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot v^{\text{flow}}_{f,k,b_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Intra-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k,b_k} \leq p^{\text{max intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{inv}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k,b_k} \geq p^{\text{min intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{inv}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Cycling Constraint

The cycling constraint for the intra-temporal constraints links the first timestep block ($b^{\text{first}}_k$) and the last one ($b^{\text{last}}_k$) in each representative period. The parameter $p^{\text{init storage level}}_{a}$ determines the considered equations in the model for this constraint:

-   If parameter $p^{\text{init storage level}}_{a}$ is not defined, the intra-storage level of the last timestep block ($b^{\text{last}}_k$) is used as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance).

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b^{\text{first}}_k} = v^{\text{intra-storage}}_{a,k,b^{\text{last}}_k}  + p^{\text{inflows}}_{a,k,b^{\text{first}}_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K}
\end{aligned}
```

-   If parameter $p^{\text{init storage level}}_{a}$ is defined, we use it as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance). In addition, the intra-storage level of the last timestep block ($b^{\text{last}}_k$) in each representative period must be greater than this initial value.

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b^{\text{first}}_k} = p^{\text{init storage level}}_{a}  + p^{\text{inflows}}_{a,k,b^{\text{first}}_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K}
\end{aligned}
```

```math
v^{\text{intra-storage}}_{a,k,b^{\text{first}}_k} \geq p^{\text{init storage level}}_{a} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K}
```

#### [Inter-temporal Constraint for Storage Balance](@id inter-storage-balance)

This constraint allows us to consider the storage seasonality throughout the model's timeframe (e.g., a year). The parameter $p^{\text{map}}_{p,k}$ determines how much of the representative period $k$ is in the period $p$, and you can use a clustering technique to calculate it. For _TulipaEnergyModel.jl_, we recommend using [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl) to compute the clusters for the representative periods and their map.

For the sake of simplicity, we show the constraint assuming the inter-storage level between two consecutive periods $p$; however, _TulipaEnergyModel.jl_ can handle more flexible period block definition through the timeframe definition in the model using the information in the file [`assets-timeframe-partitions.csv`](@ref assets-timeframe-partitions).

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p} = & v^{\text{inter-storage}}_{a,p-1} + \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
\end{aligned}
```

#### Inter-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p} \leq p^{\text{max inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{inv}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p} \geq p^{\text{min inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + p^{\text{energy to power ratio}}_a \cdot p^{\text{init capacity}}_{a} \cdot v^{\text{inv}}_{a}) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Constraint for Cycling Constraint

The cycling constraint for the inter-temporal constraints links the first-period block ($p^{\text{first}}$) and the last one ($p^{\text{last}}$) in the timeframe. The parameter $p^{\text{init storage level}}_{a}$ determines the considered equations in the model for this constraint:

-   If parameter $p^{\text{init storage level}}_{a}$ is not defined, the inter-storage level of the last period block ($p^{\text{last}}$) is used as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance).

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}} = & v^{\text{inter-storage}}_{a,p^{\text{last}}} + \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}
\end{aligned}
```

-   If parameter $p^{\text{init storage level}}_{a}$ is defined, we use it as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance). In addition, the inter-storage level of the last period block ($p^{\text{last}}$) in the timeframe must be greater than this initial value.

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}} = & p^{\text{init storage level}}_{a} + \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}
\end{aligned}
```

```math
v^{\text{inter-storage}}_{a,p^{\text{last}}} \geq p^{\text{init storage level}}_{a} \quad
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
v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init export capacity}}_{f} + p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \right)  \quad
\\ \\ \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Minimum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k,b_k} \geq - p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init import capacity}}_{f} + p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \right)  \quad
\\ \\ \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Investments

#### Maximum Investment Limit for Assets

```math
v^{\text{inv}}_{a} \leq \frac{p^{\text{inv limit}}_{a}}{p^{\text{capacity}}_{a}} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{i}}
```

If the parameter `investment_integer` in the [`assets-data.csv`](@ref assets-data) file is set to true, then the RHS of this constraint uses a least integer function (ceiling function) to guarantee that the limit is integer.

#### Maximum Investment Limit for Flows

```math
v^{\text{inv}}_{f} \leq \frac{p^{\text{inv limit}}_{f}}{p^{\text{capacity}}_{f}} \quad
\\ \\ \forall f \in \mathcal{F}^{\text{ti}}
```

If the parameter `investment_integer` in the [`flows-data.csv`](@ref flows-data) file is set to true, then the RHS of this constraint uses a least integer function (ceiling function) to guarantee that the limit is integer.

## [References](@id math-references)

Tejada-Arango, D.A., Domeshek, M., Wogrin, S., Centeno, E., 2018. Enhanced representative days and system states modeling for energy storage investment analysis. IEEE Transactions on Power Systems 33, 6534–6544. doi:10.1109/TPWRS.2018.2819578.

Tejada-Arango, D.A., Wogrin, S., Siddiqui, A.S., Centeno, E., 2019. Opportunity cost including short-term energy storage in hydrothermal dispatch models using a linked representative periods approach. Energy 188, 116079. doi:10.1016/j.energy.2019.116079.
