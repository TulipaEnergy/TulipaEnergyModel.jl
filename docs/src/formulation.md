# [Mathematical Formulation](@id formulation)

This section shows the mathematical formulation of _TulipaEnergyModel.jl_, assuming that the temporal definition of timesteps is the same for all the elements in the model.\
The [concepts section](@ref concepts) shows how the model handles the [`flexible temporal resolution`](@ref flex-time-res) of assets and flows in the model.

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

| Name                            | Description                                       | Elements | Superset                                                                                     | Notes                                                                                                                                                                                                                                                           |
| ------------------------------- | ------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| $\mathcal{A}^{\text{i}}$        | Energy assets with investment method              |          | $\mathcal{A}^{\text{i}}  \subseteq \mathcal{A}$                                              |                                                                                                                                                                                                                                                                 |
| $\mathcal{A}^{\text{ss}}$       | Energy assets with seasonal method                |          | $\mathcal{A}^{\text{ss}} \subseteq \mathcal{A}$                                              | This set contains assets that use the seasonal method method. Please visit the how-to sections for [seasonal storage](@ref seasonal-setup) and [maximum/minimum outgoing energy limit](@ref max-min-outgoing-energy-setup) to learn how to set up this feature. |
| $\mathcal{A}^{\text{se}}$       | Storage energy assets with energy method          |          | $\mathcal{A}^{\text{se}} \subseteq \mathcal{A}^{\text{s}}$                                   | This set contains storage assets that use investment energy method. Please visit the [how-to section](@ref storage-investment-setup) to learn how to set up this feature.                                                                                       |
| $\mathcal{A}^{\text{sb}}$       | Storage energy assets with binary method          |          | $\mathcal{A}^{\text{sb}} \subseteq \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}$ | This set contains storage assets that use an extra binary variable to avoid charging and discharging simultaneously. Please visit the [how-to section](@ref storage-binary-method-setup) to learn how to set up this feature.                                   |
| $\mathcal{A}^{\text{max e}}$    | Energy assets with maximum outgoing energy method |          | $\mathcal{A}^{\text{max e}} \subseteq \mathcal{A}$                                           | This set contains assets that use the maximum outgoing energy method. Please visit the [how-to section](@ref max-min-outgoing-energy-setup) to learn how to set up this feature.                                                                                |
| $\mathcal{A}^{\text{min e}}$    | Energy assets with minimum outgoing energy method |          | $\mathcal{A}^{\text{min e}} \subseteq \mathcal{A}$                                           | This set contains assets that use the minimum outgoing energy method. Please visit the [how-to section](@ref max-min-outgoing-energy-setup) to learn how to set up this feature.                                                                                |
| $\mathcal{A}^{\text{uc}}$       | Energy assets with unit commitment method         |          | $\mathcal{A}^{\text{uc}}  \subseteq \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{p}}$     | This set contains conversion and production assets that have a unit commitment method. Please visit the [how-to section](@ref unit-commitment-setup) to learn how to set up this feature.                                                                       |
| $\mathcal{A}^{\text{uc basic}}$ | Energy assets with a basic unit commitment method |          | $\mathcal{A}^{\text{uc basic}}  \subseteq \mathcal{A}^{\text{uc}}$                           | This set contains the assets that have a basic unit commitment method. Please visit the [how-to section](@ref unit-commitment-setup) to learn how to set up this feature.                                                                                       |
| $\mathcal{A}^{\text{ramp}}$     | Energy assets with ramping method                 |          | $\mathcal{A}^{\text{ramp}}  \subseteq \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{p}}$   | This set contains conversion and production assets that have a ramping method. Please visit the [how-to section](@ref ramping-setup) to learn how to set up this feature.                                                                                       |

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

### Sets for Groups

| Name                     | Description             | Elements                       | Superset | Notes |
| ------------------------ | ----------------------- | ------------------------------ | -------- | ----- |
| $\mathcal{G}^{\text{a}}$ | Groups of energy assets | $g \in \mathcal{G}^{\text{a}}$ |          |       |

In addition, the following subsets represent methods for incorporating additional constraints in the model.

| Name                      | Description                                         | Elements | Superset                                                   | Notes                                                                                                                                                            |
| ------------------------- | --------------------------------------------------- | -------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| $\mathcal{G}^{\text{ai}}$ | Group of assets that share min/max investment limit |          | $\mathcal{G}^{\text{ai}} \subseteq \mathcal{G}^{\text{a}}$ | This set contains assets that have a group investment limit. Please visit the [how-to section](@ref investment-group-setup) to learn how to set up this feature. |

## [Parameters](@id math-parameters)

### Parameter for Assets

#### General Parameters for Assets

| Name                                        | Domain                   | Domains of Indices                                                | Description                                                                                 | Units          |
| ------------------------------------------- | ------------------------ | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------- |
| $p^{\text{inv cost}}_{a}$                   | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                               | Investment cost of a unit of asset $a$                                                      | [kEUR/MW/year] |
| $p^{\text{inv limit}}_{a}$                  | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                               | Investment potential of asset $a$                                                           | [MW]           |
| $p^{\text{capacity}}_{a}$                   | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                               | Capacity per unit of asset $a$                                                              | [MW]           |
| $p^{\text{init capacity}}_{a}$              | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                               | Initial capacity of asset $a$                                                               | [MW]           |
| $p^{\text{availability profile}}_{a,k,b_k}$ | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Availability profile of asset $a$ in the representative period $k$ and timestep block $b_k$ | [p.u.]         |
| $p^{\text{group}}_{a}$                      | $\mathcal{G}^{\text{a}}$ | $a \in \mathcal{A}$                                               | Group $g$ to which the asset $a$ belongs                                                    | [-]            |

#### Extra Parameters for Consumer Assets

| Name                                  | Domain           | Domains of Indices                                                           | Description                                                                                    | Units  |
| ------------------------------------- | ---------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------ |
| $p^{\text{peak demand}}_{a}$          | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{c}}$                                               | Peak demand of consumer asset $a$                                                              | [MW]   |
| $p^{\text{demand profile}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{c}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Demand profile of consumer asset $a$ in the representative period $k$ and timestep block $b_k$ | [p.u.] |

#### Extra Parameters for Storage Assets

| Name                                   | Domain           | Domains of Indices                                                                                             | Description                                                                                                    | Units           |
| -------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------- |
| $p^{\text{init storage capacity}}_{a}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                                                                 | Initial storage capacity of storage asset $a$                                                                  | [MWh]           |
| $p^{\text{init storage level}}_{a}$    | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$                                                                                 | Initial storage level of storage asset $a$                                                                     | [MWh]           |
| $p^{\text{inflows}}_{a,k,b_k}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$                                   | Inflows of storage asset $a$ in the representative period $k$ and timestep block $b_k$                         | [MWh]           |
| $p^{\text{inv cost energy}}_{a}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$                                                                                | Investment cost of a energy unit of asset $a$                                                                  | [kEUR/MWh/year] |
| $p^{\text{inv limit energy}}_{a}$      | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$                                                                                | Investment energy potential of asset $a$                                                                       | [MWh]           |
| $p^{\text{energy capacity}}_{a}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$                                                                                | Energy capacity of a unit of investment of the asset $a$                                                       | [MWh]           |
| $p^{\text{energy to power ratio}}_a$   | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{se}}$                                               | Energy to power ratio of storage asset $a$                                                                     | [h]             |
| $p^{\text{max intra level}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}} \setminus \mathcal{A^{\text{ss}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Maximum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]          |
| $p^{\text{min intra level}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}} \setminus \mathcal{A^{\text{ss}}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Minimum intra-storage level profile of storage asset $a$ in representative period $k$ and timestep block $b_k$ | [p.u.]          |
| $p^{\text{max inter level}}_{a,p}$     | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}$, $p \in \mathcal{P}$                                                           | Maximum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]          |
| $p^{\text{min inter level}}_{a,p}$     | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}$, $p \in \mathcal{P}$                                                           | Minimum inter-storage level profile of storage asset $a$ in the period $p$ of the timeframe                    | [p.u.]          |

#### Extra Parameters for Energy Constraints

| Name                                 | Domain           | Domains of Indices                                      | Description                                                                                    | Units  |
| ------------------------------------ | ---------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------ |
| $p^{\text{min inter profile}}_{a,p}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{min e}}}$, $p \in \mathcal{P}$ | Minimum outgoing inter-temporal energy profile of asset $a$ in the period $p$ of the timeframe | [p.u.] |
| $p^{\text{max inter profile}}_{a,p}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{max e}}}$, $p \in \mathcal{P}$ | Maximum outgoing inter-temporal energy profile of asset $a$ in the period $p$ of the timeframe | [p.u.] |
| $p^{\text{max energy}}_{a,p}$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{max e}}}$                      | Maximum outgoing inter-temporal energy value of asset $a$                                      | [MWh]  |
| $p^{\text{min energy}}_{a,p}$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{min e}}}$                      | Minimum outgoing inter-temporal energy value of asset $a$                                      | [MWh]  |

#### Extra Parameters for Producers and Conversion Assets

| Name                                 | Domain           | Domains of Indices                | Description                                                                                                  | Units          |
| ------------------------------------ | ---------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------ | -------------- |
| $p^{\text{min operating point}}_{a}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{uc}}}$   | Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset $a$ | [p.u.]         |
| $p^{\text{units on cost}}_{a}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{uc}}}$   | Objective function coefficient on `units_on` variable. e.g., no-load cost or idling cost of asset $a$        | [kEUR/h/units] |
| $p^{\text{init units}}_{a}$          | $\mathbb{Z}_{+}$ | $a \in \mathcal{A^{\text{uc}}}$   | Initial number of units of asset $a$                                                                         | [units]        |
| $p^{\text{max ramp up}}_{a}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ramp}}}$ | Maximum ramping up rate as a portion of the capacity of asset $a$                                            | [p.u./h]       |
| $p^{\text{max ramp down}}_{a}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ramp}}}$ | Maximum ramping down rate as a portion of the capacity of asset $a$                                          | [p.u./h]       |

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

| Name                        | Domain           | Domains of Indices                       | Description                                                    | Units |
| --------------------------- | ---------------- | ---------------------------------------- | -------------------------------------------------------------- | ----- |
| $p^{\text{duration}}_{b_k}$ | $\mathbb{R}_{+}$ | $b_k \in \mathcal{B_k}$                  | Duration of the timestep blocks $b_k$                          | [h]   |
| $p^{\text{rp weight}}_{k}$  | $\mathbb{R}_{+}$ | $k \in \mathcal{K}$                      | Weight of representative period $k$                            | [-]   |
| $p^{\text{map}}_{p,k}$      | $\mathbb{R}_{+}$ | $p \in \mathcal{P}$, $k \in \mathcal{K}$ | Map with the weight of representative period $k$ in period $p$ | [-]   |

### Parameter for Groups

| Name                              | Domain           | Domains of Indices              | Description                                       | Units |
| --------------------------------- | ---------------- | ------------------------------- | ------------------------------------------------- | ----- |
| $p^{\text{min invest limit}}_{g}$ | $\mathbb{R}_{+}$ | $g \in \mathcal{G}^{\text{ai}}$ | Minimum investment limit (potential) of group $g$ | [MW]  |
| $p^{\text{max invest limit}}_{g}$ | $\mathbb{R}_{+}$ | $g \in \mathcal{G}^{\text{ai}}$ | Maximum investment limit (potential) of group $g$ | [MW]  |

## [Variables](@id math-variables)

| Name                                 | Domain           | Domains of Indices                                                                                             | Description                                                                                                                     | Units   |
| ------------------------------------ | ---------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------- |
| $v^{\text{flow}}_{f,k,b_k}$          | $\mathbb{R}$     | $f \in \mathcal{F}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$                                              | Flow $f$ between two assets in representative period $k$ and timestep block $b_k$                                               | [MW]    |
| $v^{\text{inv}}_{a}$                 | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}$                                                                                 | Number of invested units of asset $a$                                                                                           | [units] |
| $v^{\text{inv energy}}_{a}$          | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}} \cap \mathcal{A}^{\text{se}}$                                                    | Number of invested units of the energy component of the storage asset $a$ that use energy method                                | [units] |
| $v^{\text{inv}}_{f}$                 | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{ti}}$                                                                                | Number of invested units of capacity increment of transport flow $f$                                                            | [units] |
| $v^{\text{intra-storage}}_{a,k,b_k}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$ | Intra storage level (within a representative period) for storage asset $a$, representative period $k$, and timestep block $b_k$ | [MWh]   |
| $v^{\text{inter-storage}}_{a,p}$     | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}$, $p \in \mathcal{P}$                                                           | Inter storage level (between representative periods) for storage asset $a$ and period $p$                                       | [MWh]   |
| $v^{\text{is charging}}_{a,k,b_k}$   | $\{0, 1\}$       | $a \in \mathcal{A}^{\text{sb}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$                                  | If an storage asset $a$ is charging or not in representative period $k$ and timestep block $b_k$                                | [-]     |
| $v^{\text{units on}}_{a,k,b_k}$      | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{uc}}$, $k \in \mathcal{K}$, $b_k \in \mathcal{B_k}$                                  | Number of units ON of asset $a$ in representative period $k$ and timestep block $b_k$                                           | [units] |

## [Objective Function](@id math-objective-function)

Objective function:

```math
\begin{aligned}
\text{{minimize}} \quad & assets\_investment\_cost + flows\_investment\_cost \\
                        & + flows\_variable\_cost + unit\_on\_cost
\end{aligned}
```

Where:

```math
\begin{aligned}
assets\_investment\_cost &= \sum_{a \in \mathcal{A}^{\text{i}} } p^{\text{inv cost}}_{a} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \\ &+  \sum_{a \in \mathcal{A}^{\text{se}} \cap \mathcal{A}^{\text{i}} } p^{\text{inv cost energy}}_{a} \cdot p^{\text{energy capacity}}_{a} \cdot v^{\text{inv energy}}_{a}   \\
flows\_investment\_cost &= \sum_{f \in \mathcal{F}^{\text{ti}}} p^{\text{inv cost}}_{f} \cdot p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \\
flows\_variable\_cost &= \sum_{f \in \mathcal{F}} \sum_{k \in \mathcal{K}} \sum_{b_k \in \mathcal{B_k}} p^{\text{rp weight}}_{k} \cdot p^{\text{variable cost}}_{f} \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \\
unit\_on\_cost &= \sum_{a \in \mathcal{A}^{\text{uc}}} \sum_{k \in \mathcal{K}} \sum_{b_k \in \mathcal{B_k}} p^{\text{rp weight}}_{k} \cdot p^{\text{units on cost}}_{a} \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{units on}}_{a,k,b_k}
\end{aligned}
```

## [Constraints](@id math-constraints)

### [Capacity Constraints](@id cap-constraints)

#### Maximum Output Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{cv}} \cup \left(\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{sb}} \right) \cup \mathcal{A}^{\text{p}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

Storage assets using the method to avoid charging and discharging simultaneously, i.e., $a \in \mathcal{A}^{\text{sb}}$, use the following constraints instead of the previous one:

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{inv limit}}_{a} \right) \cdot \left(1 - v^{\text{is charging}}_{a,k,b_k} \right) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{sb}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} \cdot \left(1 - v^{\text{is charging}}_{a,k,b_k} \right) + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right) \quad
\\ \\ \forall a \in \mathcal{A}^{\text{sb}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Maximum Input Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{sb}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

Storage assets using the method to avoid charging and discharging simultaneously, i.e., $a \in \mathcal{A}^{\text{sb}}$, use the following constraints instead of the previous one:

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{inv limit}}_{a} \right)  \cdot v^{\text{is charging}}_{a,k,b_k} \quad \forall a \in \mathcal{A}^{\text{sb}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} \cdot v^{\text{is charging}}_{a,k,b_k} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)   \quad \forall a \in \mathcal{A}^{\text{sb}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Lower Limit for Flows that are not Transport Assets

```math
v^{\text{flow}}_{f,k,b_k} \geq 0 \quad \forall f \notin \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K}, \forall b_k \in \mathcal{B_k}
```

### [Unit Commitment Constraints](@id uc-constraints)

Production and conversion assets within the set $\mathcal{A}^{\text{uc}}$ will contain the unit commitment constraints in the model. These constraints are based on the work of [Morales-España et al. (2013)](https://ieeexplore.ieee.org/document/6485014) and [Morales-España et al. (2014)](https://ieeexplore.ieee.org/document/6514884).

The current version of the code only incorporates a basic unit commitment version of the constraints (i.e., utilizing only the unit commitment variable $v^{\text{units on}}$). However, upcoming versions will include more detailed constraints, incorporating startup and shutdown variables.

For the unit commitment constraints, we define the following expression for the flow that is above the minimum operating point of the asset:

```math
e^{\text{flow above min}}_{a,k,b_k} = \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} - p^{\text{availability profile}}_{a,k,b_k} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{min operating point}}_{a} \cdot v^{\text{on}}_{a,k,b_k}  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{uc}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Limit to the units on variable

```math
v^{\text{on}}_{a,k,b_k} \leq p^{\text{init units}}_{a} + v^{\text{inv}}_{a}  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{uc}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Maximum output flow above the minimum operating point

```math
e^{\text{flow above min}}_{a,k,b_k} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot p^{\text{capacity}}_{a} \cdot \left(1 - p^{\text{min operating point}}_{a} \right) \cdot v^{\text{on}}_{a,k,b_k}  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{uc basic}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Minimum output flow above the minimum operating point

```math
e^{\text{flow above min}}_{a,k,b_k} \geq 0  \quad
\\ \\ \forall a \in \mathcal{A}^{\text{uc basic}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

### [Ramping Constraints](@id ramp-constraints)

Ramping constraints restrict the rate at which the output flow of a production or conversion asset can change. If the asset is part of the unit commitment set (e.g., $\mathcal{A}^{\text{uc}}$), the ramping limits apply to the flow above the minimum output, but if it is not, the ramping limits apply to the total output flow.

Ramping constraints that take into account unit commitment variables are based on the work done by [Damcı-Kurt et. al (2016)](https://link.springer.com/article/10.1007/s10107-015-0919-9). Also, please note that since the current version of the code only handles the basic unit commitment implementation, the ramping constraints are applied to the assets in the set $\mathcal{A}^{\text{uc basic}}$.

#### Maximum ramp-up rate limit with unit commitment method

```math
e^{\text{flow above min}}_{a,k,b_k} - e^{\text{flow above min}}_{a,k,b_k-1} \leq p^{\text{availability profile}}_{a,k,b_k} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{max ramp up}}_{a} \cdot v^{\text{on}}_{a,k,b_k}  \quad
\\ \\ \forall a \in \left(\mathcal{A}^{\text{ramp}} \cap \mathcal{A}^{\text{uc basic}} \right), \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Maximum ramp-down rate limit with unit commitment method

```math
e^{\text{flow above min}}_{a,k,b_k} - e^{\text{flow above min}}_{a,k,b_k-1} \geq - p^{\text{availability profile}}_{a,k,b_k} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{max ramp down}}_{a} \cdot v^{\text{on}}_{a,k,b_k}  \quad
\\ \\ \forall a \in \left(\mathcal{A}^{\text{ramp}} \cap \mathcal{A}^{\text{uc basic}} \right), \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Maximum ramp-up rate limit without unit commitment method

```math
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k-1} \leq p^{\text{max ramp up}}_{a} \cdot p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
\\ \\ \forall a \in \left(\mathcal{A}^{\text{ramp}} \setminus \mathcal{A}^{\text{uc basic}} \right), \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Maximum ramp-down rate limit without unit commitment method

```math
\sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k-1} \geq - p^{\text{max ramp down}}_{a} \cdot p^{\text{availability profile}}_{a,k,b_k} \cdot \left(p^{\text{init capacity}}_{a} + p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \right)  \quad
\\ \\ \forall a \in \left(\mathcal{A}^{\text{ramp}} \setminus \mathcal{A}^{\text{uc basic}} \right), \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

### Constraints for Energy Consumer Assets

#### Balance Constraint for Consumers

The balance constraint sense depends on the method selected in the asset file's parameter [`consumer_balance_sense`](@ref schemas). The default value is $=$, but the user can choose $\geq$ as an option.

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \left\{\begin{array}{l} = \\ \geq \end{array}\right\} p^{\text{demand profile}}_{a,k,b_k} \cdot p^{\text{peak demand}}_{a} \quad \forall a \in \mathcal{A}^{\text{c}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Energy Storage Assets

There are two types of constraints for energy storage assets: intra-temporal and inter-temporal. Intra-temporal constraints impose limits inside a representative period, while inter-temporal constraints combine information from several representative periods (e.g., to model seasonal storage). For more information on this topic, refer to the [concepts section](@ref storage-modeling) or [Tejada-Arango et al. (2018)](https://ieeexplore.ieee.org/document/8334256) and [Tejada-Arango et al. (2019)](https://www.sciencedirect.com/science/article/pii/S0360544219317748).

In addition, we define the following expression to determine the energy investment limit of the storage assets. This expression takes two different forms depending on whether the storage asset belongs to the set $\mathcal{A}^{\text{se}}$ or not.

-   Investment energy method:

```math
e^{\text{energy inv limit}}_{a} = p^{\text{energy capacity}}_a \cdot v^{\text{inv energy}}_{a} \quad \forall a \in \mathcal{A}^{\text{i}} \cap \mathcal{A}^{\text{se}}
```

-   Fixed energy-to-power ratio method:

```math
e^{\text{energy inv limit}}_{a} = p^{\text{energy to power ratio}}_a \cdot p^{\text{capacity}}_a \cdot v^{\text{inv}}_{a} \quad \forall a \in \mathcal{A}^{\text{i}} \cap (\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{se}})
```

#### [Intra-temporal Constraint for Storage Balance](@id intra-storage-balance)

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b_k} = v^{\text{intra-storage}}_{a,k,b_k-1}  + p^{\text{inflows}}_{a,k,b_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Intra-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k,b_k} \leq p^{\text{max intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + e^{\text{energy inv limit}}_{a}) \quad \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k,b_k} \geq p^{\text{min intra level}}_{a,k,b_k} \cdot (p^{\text{init storage capacity}}_{a} + e^{\text{energy inv limit}}_{a}) \quad \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
```

#### Intra-temporal Cycling Constraint

The cycling constraint for the intra-temporal constraints links the first timestep block ($b^{\text{first}}_k$) and the last one ($b^{\text{last}}_k$) in each representative period. The parameter $p^{\text{init storage level}}_{a}$ determines the considered equations in the model for this constraint:

-   If parameter $p^{\text{init storage level}}_{a}$ is not defined, the intra-storage level of the last timestep block ($b^{\text{last}}_k$) is used as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance).

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b^{\text{first}}_k} = v^{\text{intra-storage}}_{a,k,b^{\text{last}}_k}  + p^{\text{inflows}}_{a,k,b^{\text{first}}_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} \quad
\\ \\ \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k \in \mathcal{K}
\end{aligned}
```

-   If parameter $p^{\text{init storage level}}_{a}$ is defined, we use it as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance). In addition, the intra-storage level of the last timestep block ($b^{\text{last}}_k$) in each representative period must be greater than this initial value.

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k,b^{\text{first}}_k} = p^{\text{init storage level}}_{a}  + p^{\text{inflows}}_{a,k,b^{\text{first}}_k} + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \cdot p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b^{\text{first}}_k} \quad
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
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
\end{aligned}
```

#### Inter-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p} \leq p^{\text{max inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + e^{\text{energy inv limit}}_{a}) \quad \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p} \geq p^{\text{min inter level}}_{a,p} \cdot (p^{\text{init storage capacity}}_{a} + e^{\text{energy inv limit}}_{a}) \quad \forall a \in \mathcal{A}^{\text{ss}}, \forall p \in \mathcal{P}
```

#### Inter-temporal Cycling Constraint

The cycling constraint for the inter-temporal constraints links the first-period block ($p^{\text{first}}$) and the last one ($p^{\text{last}}$) in the timeframe. The parameter $p^{\text{init storage level}}_{a}$ determines the considered equations in the model for this constraint:

-   If parameter $p^{\text{init storage level}}_{a}$ is not defined, the inter-storage level of the last period block ($p^{\text{last}}$) is used as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance).

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}} = & v^{\text{inter-storage}}_{a,p^{\text{last}}} + \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k}
\\ \\ & \forall a \in \mathcal{A}^{\text{ss}}
\end{aligned}
```

-   If parameter $p^{\text{init storage level}}_{a}$ is defined, we use it as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance). In addition, the inter-storage level of the last period block ($p^{\text{last}}$) in the timeframe must be greater than this initial value.

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}} = & p^{\text{init storage level}}_{a} + \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{inflows}}_{a,k,b_k} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{1}{p^{\text{eff}}_f} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p^{\text{first}},k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k}
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
\sum_{f \in \mathcal{F}^{\text{in}}_a} v^{\text{flow}}_{f,k,b_k} = \sum_{f \in \mathcal{F}^{\text{out}}_a} v^{\text{flow}}_{f,k,b_k} \quad \forall a \in \mathcal{A}^{\text{h}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Energy Conversion Assets

#### Balance Constraint for Conversion Assets

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_a} p^{\text{eff}}_f \cdot v^{\text{flow}}_{f,k,b_k} = \sum_{f \in \mathcal{F}^{\text{out}}_a} \frac{v^{\text{flow}}_{f,k,b_k}}{p^{\text{eff}}_f} \quad \forall a \in \mathcal{A}^{\text{cv}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Transport Assets

#### Maximum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k,b_k} \leq p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init export capacity}}_{f} + p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \right)  \quad \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

#### Minimum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k,b_k} \geq - p^{\text{availability profile}}_{f,k,b_k} \cdot \left(p^{\text{init import capacity}}_{f} + p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f} \right)  \quad \forall f \in \mathcal{F}^{\text{t}}, \forall k \in \mathcal{K},\forall b_k \in \mathcal{B_k}
\end{aligned}
```

### Constraints for Investments

#### Maximum Investment Limit for Assets

```math
v^{\text{inv}}_{a} \leq \frac{p^{\text{inv limit}}_{a}}{p^{\text{capacity}}_{a}} \quad \forall a \in \mathcal{A}^{\text{i}}
```

If the parameter `investment_integer` in the [`assets-data.csv`](@ref assets-data) file is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

#### Maximum Energy Investment Limit for Assets

```math
v^{\text{inv energy}}_{a} \leq \frac{p^{\text{inv limit energy}}_{a}}{p^{\text{energy capacity}}_{a}} \quad \forall a \in \mathcal{A}^{\text{i}} \cap \mathcal{A}^{\text{se}}
```

If the parameter `investment_integer_storage_energy` in the [`assets-data.csv`](@ref assets-data) file is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

#### Maximum Investment Limit for Flows

```math
v^{\text{inv}}_{f} \leq \frac{p^{\text{inv limit}}_{f}}{p^{\text{capacity}}_{f}} \quad \forall f \in \mathcal{F}^{\text{ti}}
```

If the parameter `investment_integer` in the [`flows-data.csv`](@ref flows-data) file is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

### [Inter-temporal Energy Constraints](@id inter-temporal-energy-constraints)

These constraints allow us to consider a maximum or minimum energy limit for an asset throughout the model's timeframe (e.g., a year). It uses the same principle explained in the [inter-temporal constraint for storage balance](@ref inter-storage-balance) and in the [Storage Modeling](@ref storage-modeling) section.

#### Maximum Outgoing Energy During the Timeframe

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \leq  p^{\text{max inter profile}}_{a,p} \cdot p^{\text{max energy}}_{a}
\\ \\ & \forall a \in \mathcal{A}^{\text{max e}}, \forall p \in \mathcal{P}
\end{aligned}
```

#### Minimum Outgoing Energy During the Timeframe

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_a} \sum_{k \in \mathcal{K}} p^{\text{map}}_{p,k} \sum_{b_k \in \mathcal{B_K}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k,b_k} \geq  p^{\text{min inter profile}}_{a,p} \cdot p^{\text{min energy}}_{a}
\\ \\ & \forall a \in \mathcal{A}^{\text{min e}}, \forall p \in \mathcal{P}
\end{aligned}
```

### [Constraints for Groups](@id group-constraints)

The following constraints aggregate variables of different assets depending on the method that applies to the group.

#### [Investment Limits of a Group](@id investment-group-constraints)

These constraints apply to assets in a group using the investment method $\mathcal{G}^{\text{ai}}$. They help impose an investment potential of a spatial area commonly shared by several assets that can be invested there.

##### Minimum Investment Limit of a Group

```math
\begin{aligned}
\sum_{a \in \mathcal{A}^{\text{i}} | p^{\text{group}}_{a} = g} p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \geq  p^{\text{min invest limit}}_{g}
\\ \\ & \forall g \in \mathcal{G}^{\text{ai}}
\end{aligned}
```

##### Maximum Investment Limit of a Group

```math
\begin{aligned}
\sum_{a \in \mathcal{A}^{\text{i}} | p^{\text{group}}_{a} = g} p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a} \leq  p^{\text{max invest limit}}_{g}
\\ \\ & \forall g \in \mathcal{G}^{\text{ai}}
\end{aligned}
```

## [References](@id math-references)

Damcı-Kurt, P., Küçükyavuz, S., Rajan, D., Atamtürk, A., 2016. A polyhedral study of production ramping. Math. Program. 158, 175–205. doi: 10.1007/s10107-015-0919-9.

Morales-España, G., Ramos, A., García-González, J., 2014. An MIP Formulation for Joint Market-Clearing of Energy and Reserves Based on Ramp Scheduling. IEEE Transactions on Power Systems 29, 476-488. doi: 10.1109/TPWRS.2013.2259601.

Morales-España, G., Latorre, J. M., Ramos, A., 2013. Tight and Compact MILP Formulation for the Thermal Unit Commitment Problem. IEEE Transactions on Power Systems 28, 4897-4908. doi: 10.1109/TPWRS.2013.2251373.

Tejada-Arango, D.A., Domeshek, M., Wogrin, S., Centeno, E., 2018. Enhanced representative days and system states modeling for energy storage investment analysis. IEEE Transactions on Power Systems 33, 6534–6544. doi:10.1109/TPWRS.2018.2819578.

Tejada-Arango, D.A., Wogrin, S., Siddiqui, A.S., Centeno, E., 2019. Opportunity cost including short-term energy storage in hydrothermal dispatch models using a linked representative periods approach. Energy 188, 116079. doi:10.1016/j.energy.2019.116079.
