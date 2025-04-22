# [Mathematical Formulation](@id formulation)

This section shows the mathematical formulation of _TulipaEnergyModel.jl_, assuming that the temporal definition of timesteps is the same for all the elements in the model (e.g., hourly). The [concepts section](@ref concepts) shows how the model handles the [`flexible temporal resolution`](@ref flex-time-res) of assets and flows in the model.

```@contents
Pages = ["40-formulation.md"]
Depth = [2,3]
```

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

| Name                                      | Description                                                   | Elements | Superset                                                                                         | Notes                                                                                                                                                                                                                                                           |
| ----------------------------------------- | ------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| $\mathcal{A}^{\text{i}}_y$                | Energy assets with investment method at year $y$              |          | $\mathcal{A}^{\text{i}}_y  \subseteq \mathcal{A}$                                                |                                                                                                                                                                                                                                                                 |
| $\mathcal{A}^{\text{operation}}$          | Energy assets with operation mode at year $y$                 |          | $\mathcal{A}^{\text{operation}}  \subseteq \mathcal{A}$                                          |                                                                                                                                                                                                                                                                 |
| $\mathcal{A}^{\text{simple investment}}$  | Energy assets with simple investment method at year $y$       |          | $\mathcal{A}^{\text{simple investment}}  \subseteq \mathcal{A}$                                  |                                                                                                                                                                                                                                                                 |
| $\mathcal{A}^{\text{compact investment}}$ | Energy assets with compact investment method at year $y$      |          | $\mathcal{A}^{\text{compact investment}}  \subseteq \mathcal{A}$                                 |                                                                                                                                                                                                                                                                 |
| $\mathcal{A}^{\text{ss}}_y$               | Energy assets with seasonal method at year $y$                |          | $\mathcal{A}^{\text{ss}}_y \subseteq \mathcal{A}$                                                | This set contains assets that use the seasonal method method. Please visit the how-to sections for [seasonal storage](@ref seasonal-setup) and [maximum/minimum outgoing energy limit](@ref max-min-outgoing-energy-setup) to learn how to set up this feature. |
| $\mathcal{A}^{\text{se}}_y$               | Storage energy assets with energy method at year $y$          |          | $\mathcal{A}^{\text{se}}_y \subseteq \mathcal{A}^{\text{s}}$                                     | This set contains storage assets that use investment energy method. Please visit the [how-to section](@ref storage-investment-setup) to learn how to set up this feature.                                                                                       |
| $\mathcal{A}^{\text{sb}}_y$               | Storage energy assets with binary method at year $y$          |          | $\mathcal{A}^{\text{sb}}_y \subseteq \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}_y$ | This set contains storage assets that use an extra binary variable to avoid charging and discharging simultaneously. Please visit the [how-to section](@ref storage-binary-method-setup) to learn how to set up this feature.                                   |
| $\mathcal{A}^{\text{max e}}_y$            | Energy assets with maximum outgoing energy method at year $y$ |          | $\mathcal{A}^{\text{max e}}_y \subseteq \mathcal{A}$                                             | This set contains assets that use the maximum outgoing energy method. Please visit the [how-to section](@ref max-min-outgoing-energy-setup) to learn how to set up this feature.                                                                                |
| $\mathcal{A}^{\text{min e}}_y$            | Energy assets with minimum outgoing energy method at year $y$ |          | $\mathcal{A}^{\text{min e}} _y\subseteq \mathcal{A}$                                             | This set contains assets that use the minimum outgoing energy method. Please visit the [how-to section](@ref max-min-outgoing-energy-setup) to learn how to set up this feature.                                                                                |
| $\mathcal{A}^{\text{uc}}_y$               | Energy assets with unit commitment method at year $y$         |          | $\mathcal{A}^{\text{uc}}_y  \subseteq \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{p}}$       | This set contains conversion and production assets that have a unit commitment method. Please visit the [how-to section](@ref unit-commitment-setup) to learn how to set up this feature.                                                                       |
| $\mathcal{A}^{\text{uc basic}}_y$         | Energy assets with a basic unit commitment method at year $y$ |          | $\mathcal{A}^{\text{uc basic}}_y \subseteq \mathcal{A}^{\text{uc}}_y$                            | This set contains the assets that have a basic unit commitment method. Please visit the [how-to section](@ref unit-commitment-setup) to learn how to set up this feature.                                                                                       |
| $\mathcal{A}^{\text{ramp}}_y$             | Energy assets with ramping method at year $y$                 |          | $\mathcal{A}^{\text{ramp}}_y  \subseteq \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{p}}$     | This set contains conversion and production assets that have a ramping method. Please visit the [how-to section](@ref ramping-setup) to learn how to set up this feature.                                                                                       |
| $\mathcal{A}^{\text{dc-opf}}_y$           | Energy assets with a DC power flow method at year $y$         |          | $\mathcal{A}^{\text{dc-opf}}_y \subseteq \mathcal{A}$                                            | This set contains the assets that have that use the dc-opf method.                                                                                                                                                                                              |

### Sets for Flows

| Name                             | Description                                     | Elements            | Superset                                               | Notes |
| -------------------------------- | ----------------------------------------------- | ------------------- | ------------------------------------------------------ | ----- |
| $\mathcal{F}$                    | Flow connections between two assets             | $f \in \mathcal{F}$ |                                                        |       |
| $\mathcal{F}^{\text{in}}_{a,y}$  | Set of flows going into asset $a$ at year $y$   |                     | $\mathcal{F}^{\text{in}}_{a,y}  \subseteq \mathcal{F}$ |       |
| $\mathcal{F}^{\text{out}}_{a,y}$ | Set of flows going out of asset $a$ at year $y$ |                     | $\mathcal{F}^{\text{out}}_{a,y} \subseteq \mathcal{F}$ |       |

In addition, the following flow sets represent methods for incorporating additional variables and constraints in the model.

| Name                            | Description                                                     | Elements | Superset                                                     | Notes                                               |
| ------------------------------- | --------------------------------------------------------------- | -------- | ------------------------------------------------------------ | --------------------------------------------------- |
| $\mathcal{F}^{\text{t}}$        | Flow between two assets with a transport method                 |          | $\mathcal{F}^{\text{t}} \subseteq \mathcal{F}$               |                                                     |
| $\mathcal{F}^{\text{ti}}_y$     | Transport flow with investment method at year $y$               |          | $\mathcal{F}^{\text{ti}}_y \subseteq \mathcal{F}^{\text{t}}$ |                                                     |
| $\mathcal{F}^{\text{dc-opf}}_y$ | Flow between two assets with a DC power flow method at year $y$ |          | $\mathcal{F}^{\text{dc-opf}}_y \subseteq \mathcal{F}$        | This set contains flows that use the dc-opf method. |

### Sets for Temporal Structures

| Name                | Description                                                       | Elements                        | Superset                           | Notes                                                                            |
| ------------------- | ----------------------------------------------------------------- | ------------------------------- | ---------------------------------- | -------------------------------------------------------------------------------- |
| $\mathcal{Y}$       | Milestone years                                                   | $y \in \mathcal{Y}$             | $\mathcal{Y} \subset \mathbb{N}$   |                                                                                  |
| $\mathcal{V}$       | All years                                                         | $v \in \mathcal{V}$             | $\mathcal{V} \subset \mathbb{N}$   |                                                                                  |
| $\mathcal{P}_y$     | Periods in the timeframe at year $y$                              | $p_y \in \mathcal{P}_y$         | $\mathcal{P}_y \subset \mathbb{N}$ |                                                                                  |
| $\mathcal{K}_y$     | Representative periods (rp) at year $y$                           | $k_y \in \mathcal{K}_y$         | $\mathcal{K}_y \subset \mathbb{N}$ | $\mathcal{K}_y$ does not have to be a subset of $\mathcal{P}_y$                  |
| $\mathcal{B}_{k_y}$ | Timesteps blocks within a representative period $k_y$ at year $y$ | $b_{k_y} \in \mathcal{B}_{k_y}$ |                                    | $\mathcal{B}_{k_y}$ is a partition of timesteps in a representative period $k_y$ |

### Sets for Groups

| Name                     | Description             | Elements                       | Superset | Notes |
| ------------------------ | ----------------------- | ------------------------------ | -------- | ----- |
| $\mathcal{G}^{\text{a}}$ | Groups of energy assets | $g \in \mathcal{G}^{\text{a}}$ |          |       |

In addition, the following subsets represent methods for incorporating additional constraints in the model.

| Name                        | Description                                         | Elements | Superset                                                     | Notes                                                                                                                                                            |
| --------------------------- | --------------------------------------------------- | -------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| $\mathcal{G}^{\text{ai}}_y$ | Group of assets that share min/max investment limit |          | $\mathcal{G}^{\text{ai}}_y \subseteq \mathcal{G}^{\text{a}}$ | This set contains assets that have a group investment limit. Please visit the [how-to section](@ref investment-group-setup) to learn how to set up this feature. |

## [Parameters](@id math-parameters)

### Parameters for Assets

#### General Parameters for Assets

| Name                                                 | Domain                   | Domains of Indices                                                                                 | Description                                                                                                            | Units          |
| ---------------------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------- |
| $p^{\text{inv cost}}_{a,y}$                          | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Overnight cost of a unit of asset $a$ at year $y$                                                                      | [kEUR/MW]      |
| $p^{\text{annualized inv cost}}_{a,y}$               | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Annualized investment cost of a unit of asset $a$ at year $y$                                                          | [kEUR/MW/year] |
| $p^{\text{salvage value}}_{a,y}$                     | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Salvage value of a unit of asset $a$ at year $y$                                                                       | [kEUR/MW]      |
| $p^{\text{discounting factor asset inv cost}}_{a,y}$ | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Discounting factor for investment cost of a unit of asset $a$ at year $y$                                              | [-]            |
| $p^{\text{fixed cost}}_{a,y}$                        | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Fixed cost of a unit of asset $a$ at year $y$                                                                          | [kEUR/MW/year] |
| $p^{\text{inv limit}}_{a,y}$                         | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Investment potential of asset $a$ at year $y$                                                                          | [MW]           |
| $p^{\text{capacity}}_{a}$                            | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                                                                | Capacity per unit of asset $a$                                                                                         | [MW]           |
| $p^{\text{technical lifetime}}_{a}$                  | $\mathbb{Z}_{+}$         | $a \in \mathcal{A}$                                                                                | Technical lifetime of asset $a$                                                                                        | [year]         |
| $p^{\text{economic lifetime}}_{a}$                   | $\mathbb{Z}_{+}$         | $a \in \mathcal{A}$                                                                                | Economic lifetime of asset $a$                                                                                         | [year]         |
| $p^{\text{technology-specific discount rate}}_{a}$   | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$                                                                                | Technology-specific discount rate of asset $a$                                                                         | [year]         |
| $p^{\text{init units}}_{a,y}$                        | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $y \in \mathcal{Y}$                                                           | Initial number of units of asset $a$ available at year $y$                                                             | [units]        |
| $p^{\text{init units}}_{a,y,v}$                      | $\mathbb{R}_{+}$         | $ (a,y,v) \in \mathcal{D}^{\text{compact investment}} \cup \mathcal{D}^{\text{operation}}$         | Initial number of units of asset $a$ available at year $y$ commissioned in year $v$                                    | [units]        |
| $p^{\text{availability profile}}_{a,v,k_y,b_{k_y}}$  | $\mathbb{R}_{+}$         | $a \in \mathcal{A}$, $v \in \mathcal{V}$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Availability profile of asset $a$ invested in year $v$ in the representative period $k_y$ and timestep block $b_{k_y}$ | [p.u.]         |
| $p^{\text{group}}_{a}$                               | $\mathcal{G}^{\text{a}}$ | $a \in \mathcal{A}$                                                                                | Group $g$ to which the asset $a$ belongs                                                                               | [-]            |

#### Extra Parameters for Consumer Assets

| Name                                        | Domain           | Domains of Indices                                                                                              | Description                                                                                          | Units  |
| ------------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------ |
| $p^{\text{peak demand}}_{a,y}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{c}}$, $y \in \mathcal{Y}$                                                             | Peak demand of consumer asset $a$ at year $y$                                                        | [MW]   |
| $p^{\text{demand profile}}_{a,k_y,b_{k_y}}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{c}}}$, , $y \in \mathcal{Y}$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Demand profile of consumer asset $a$ in the representative period $k_y$ and timestep block $b_{k_y}$ | [p.u.] |

#### Extra Parameters for Storage Assets

| Name                                               | Domain           | Domains of Indices                                                                                                           | Description                                                                                                          | Units           |
| -------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | --------------- |
| $p^{\text{init storage units}}_{a,y}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$, $y \in \mathcal{Y}$                                                                          | Initial storage units of storage asset $a$ available at year $y$                                                     | [units]         |
| $p^{\text{init storage level}}_{a,y}$              | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}$, $y \in \mathcal{Y}$                                                                          | Initial storage level of storage asset $a$ at year $y$                                                               | [MWh]           |
| $p^{\text{inflows}}_{a,k_y,b_{k_y}}$               | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$                                     | Inflows of storage asset $a$ in the representative period $k_y$ and timestep block $b_{k_y}$                         | [MWh]           |
| $p^{\text{inv cost energy}}_{a,y}$                 | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$, $y \in \mathcal{Y}$                                                                         | Overnight cost of a energy unit of asset $a$ at year $y$                                                             | [kEUR/MWh]      |
| $p^{\text{fixed cost energy}}_{a,y}$               | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$, $y \in \mathcal{Y}$                                                                         | Fixed cost of a energy unit of asset $a$ at year $y$                                                                 | [kEUR/MWh/year] |
| $p^{\text{inv limit energy}}_{a,y}$                | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$, $y \in \mathcal{Y}$                                                                         | Investment energy potential of asset $a$ at year $y$                                                                 | [MWh]           |
| $p^{\text{energy capacity}}_{a}$                   | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{se}}$                                                                                              | Energy capacity of a unit of investment of the asset $a$                                                             | [MWh]           |
| $p^{\text{energy to power ratio}}_{a,y}$           | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{se}}_y$                                                           | Energy to power ratio of storage asset $a$ at year $y$                                                               | [h]             |
| $p^{\text{max intra level}}_{a,k_y,b_{k_y}}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}} \setminus \mathcal{A^{\text{ss}}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Maximum intra-storage level profile of storage asset $a$ in representative period $k_y$ and timestep block $b_{k_y}$ | [p.u.]          |
| $p^{\text{min intra level}}_{a,k_y,b_{k_y}}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}} \setminus \mathcal{A^{\text{ss}}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Minimum intra-storage level profile of storage asset $a$ in representative period $k_y$ and timestep block $b_{k_y}$ | [p.u.]          |
| $p^{\text{max inter level}}_{a,p_y}$               | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}_y$, $p_y \in \mathcal{P}_y$                                                                   | Maximum inter-storage level profile of storage asset $a$ in the period $p_y$ of the timeframe                        | [p.u.]          |
| $p^{\text{min inter level}}_{a,p_y}$               | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}_y$, $p_y \in \mathcal{P}_y$                                                                   | Minimum inter-storage level profile of storage asset $a$ in the period $p_y$ of the timeframe                        | [p.u.]          |
| $p^{\text{storage loss from stored energy}}_{a,y}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{s}}}$, $y \in \mathcal{Y}_y$                                                                        | [e.g. 0.01 means 1% every hour] Loss of stored energy over time.                                                     | [p.u./h]        |

#### Extra Parameters for Energy Constraints

| Name                                   | Domain           | Domains of Indices                                            | Description                                                                                      | Units  |
| -------------------------------------- | ---------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------ |
| $p^{\text{min inter profile}}_{a,p_y}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{min e}}}_y$, $p_y \in \mathcal{P}_y$ | Minimum outgoing inter-temporal energy profile of asset $a$ in the period $p_y$ of the timeframe | [p.u.] |
| $p^{\text{max inter profile}}_{a,p_y}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{max e}}}_y$, $p_y \in \mathcal{P}_y$ | Maximum outgoing inter-temporal energy profile of asset $a$ in the period $p_y$ of the timeframe | [p.u.] |
| $p^{\text{max energy}}_{a,p_y}$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{max e}}}_y$                          | Maximum outgoing inter-temporal energy value of asset $a$                                        | [MWh]  |
| $p^{\text{min energy}}_{a,p_y}$        | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{min e}}}_y$                          | Minimum outgoing inter-temporal energy value of asset $a$                                        | [MWh]  |

#### Extra Parameters for Producers and Conversion Assets

| Name                                   | Domain           | Domains of Indices                  | Description                                                                                                              | Units          |
| -------------------------------------- | ---------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------- |
| $p^{\text{min operating point}}_{a,y}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{uc}}}_y$   | Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset $a$ at year $y$ | [p.u.]         |
| $p^{\text{units on cost}}_{a,y}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{uc}}}_y$   | Objective function coefficient on `units_on` variable. e.g., no-load cost or idling cost of asset $a$ at year $y$        | [kEUR/h/units] |
| $p^{\text{max ramp up}}_{a,y}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ramp}}}_y$ | Maximum ramping up rate as a portion of the capacity of asset $a$ at year $y$                                            | [p.u./h]       |
| $p^{\text{max ramp down}}_{a,y}$       | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ramp}}}_y$ | Maximum ramping down rate as a portion of the capacity of asset $a$ at year $y$                                          | [p.u./h]       |

### Parameters for Flows

| Name                                                | Domain           | Domains of Indices                                                                                 | Description                                                                                                           | Units          |
| --------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | -------------- |
| $p^{\text{variable cost}}_{f,y}$                    | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$, $y \in \mathcal{Y}$                                                           | Variable cost of flow $f$ at year $y$                                                                                 | [kEUR/MWh]     |
| $p^{\text{eff}}_{f,y}$                              | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$, $y \in \mathcal{Y}$                                                           | Efficiency of flow $f$ at year $y$                                                                                    | [p.u.]         |
| $p^{\text{reactance}}_{f,y}$                        | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$, $y \in \mathcal{Y}$                                                           | Reactance of flow $f$ at year $y$                                                                                     | [p.u.]         |
| $p^{\text{capacity coefficient}}_{f,y}$             | $\mathbb{R}_{+}$ | $f \in \mathcal{F}$, $y \in \mathcal{Y}$                                                           | Coefficient that multiplies the flow $f$ at year $y$ in the capacity constraints                                      | [-]            |
| $p^{\text{inv cost}}_{f,y}$                         | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Overnight cost of transport flow $f$ at year $y$                                                                      | [kEUR/MW]      |
| $p^{\text{annualized inv cost}}_{f,y}$              | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Annualized investment cost of transport flow $f$ at year $y$                                                          | [kEUR/MW/year] |
| $p^{\text{salvage value}}_{f,y}$                    | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Salvage value of transport flow $f$ at year $y$                                                                       | [kEUR/MW]      |
| $p^{\text{discounting factor flow inv cost}}_{f,y}$ | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Discounting factor for investment cost of transport flow $f$ at year $y$                                              | [-]            |
| $p^{\text{fixed cost}}_{f,y}$                       | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Fixed cost of transport flow $f$ at year $y$                                                                          | [kEUR/MW/year] |
| $p^{\text{inv limit}}_{f,y}$                        | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Investment potential of flow $f$ at year $y$                                                                          | [MW]           |
| $p^{\text{capacity}}_{f}$                           | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                                                     | Capacity per unit of investment of transport flow $f$ (both exports and imports)                                      | [MW]           |
| $p^{\text{technical lifetime}}_{f}$                 | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                                                     | Technical lifetime of investment of transport flow $f$ (both exports and imports)                                     | [year]         |
| $p^{\text{economic lifetime}}_{f}$                  | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                                                     | Economic lifetime of investment of transport flow $f$ (both exports and imports)                                      | [year]         |
| $p^{\text{technology-specific discount rate}}_{f}$  | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$                                                                     | Technology-specific discount rate of investment of transport flow $f$ (both exports and imports)                      | [year]         |
| $p^{\text{init export units}}_{f,y}$                | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Initial export units of transport flow $f$ available at year $y$                                                      | [MW]           |
| $p^{\text{init import units}}_{f,y}$                | $\mathbb{R}_{+}$ | $f \in \mathcal{F}^{\text{t}}$, $y \in \mathcal{Y}$                                                | Initial import units of transport flow $f$ available at year $y$                                                      | [MW]           |
| $p^{\text{availability profile}}_{f,v,k_y,b_{k_y}}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{F}$, $v \in \mathcal{V}$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Availability profile of flow $f$ invested in year $v$ in the representative period $k_y$ and timestep block $b_{k_y}$ | [p.u.]         |

### Parameters for Temporal Structures

| Name                            | Domain           | Domains of Indices                               | Description                                                        | Units |
| ------------------------------- | ---------------- | ------------------------------------------------ | ------------------------------------------------------------------ | ----- |
| $p^{\text{duration}}_{b_{k_y}}$ | $\mathbb{R}_{+}$ | $b_{k_y} \in \mathcal{B_{k_y}}$                  | Duration of the timestep blocks $b_{k_y}$                          | [h]   |
| $p^{\text{rp weight}}_{k_y}$    | $\mathbb{R}_{+}$ | $k_y \in \mathcal{K}_y$                          | Weight of representative period $k_y$                              | [-]   |
| $p^{\text{map}}_{p_y,k_y}$      | $\mathbb{R}_{+}$ | $p_y \in \mathcal{P}_y$, $k_y \in \mathcal{K}_y$ | Map with the weight of representative period $k_y$ in period $p_y$ | [-]   |

### Parameters for Groups

| Name                                | Domain           | Domains of Indices                                   | Description                                                   | Units |
| ----------------------------------- | ---------------- | ---------------------------------------------------- | ------------------------------------------------------------- | ----- |
| $p^{\text{min invest limit}}_{g,y}$ | $\mathbb{R}_{+}$ | $g \in \mathcal{G}^{\text{ai}}$, $y \in \mathcal{Y}$ | Minimum investment limit (potential) of group $g$ at year $y$ | [MW]  |
| $p^{\text{max invest limit}}_{g,y}$ | $\mathbb{R}_{+}$ | $g \in \mathcal{G}^{\text{ai}}$, $y \in \mathcal{Y}$ | Maximum investment limit (potential) of group $g$ at year $y$ | [MW]  |

### Parameters for the Model

| Name                              | Domain           | Description          | Units  |
| --------------------------------- | ---------------- | -------------------- | ------ |
| $p^{\text{social discount rate}}$ | $\mathbb{R}_{+}$ | Social discount rate | [-]    |
| $p^{\text{discount year}}$        | $\mathbb{Z}_{+}$ | Discount year        | [year] |
| $p^{\text{power system base}}$    | $\mathbb{R}_{+}$ | Power system base    | [MVA]  |

### Extra Parameters for Discounting

| Name                                               | Domain           | Domains of Indices  | Description                                       | Units |
| -------------------------------------------------- | ---------------- | ------------------- | ------------------------------------------------- | ----- |
| $p^{\text{discounting factor operation cost}}_{y}$ | $\mathbb{R}_{+}$ | $y \in \mathcal{Y}$ | Discounting factor for operation cost at year $y$ | [-]   |

## [Variables](@id math-variables)

| Name                                       | Domain           | Domains of Indices                                                                                                             | Description                                                                                                                           | Units   |
| ------------------------------------------ | ---------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| $v^{\text{flow}}_{f,k_y,b_{k_y}}$          | $\mathbb{R}$     | $f \in \mathcal{F}$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$                                                  | Flow $f$ between two assets in representative period $k_y$ and timestep block $b_{k_y}$                                               | [MW]    |
| $v^{\text{inv}}_{a,y}$                     | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}_y$, $y \in \mathcal{Y}$                                                                          | Number of invested units of asset $a$ at year $y$                                                                                     | [units] |
| $v^{\text{decom simple}}_{a,y}$            | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{simple investment}}$, $y \in \mathcal{Y}$                                                            | Number of decommissioned units of asset $a$ that uses simple investment method at year $y$                                            | [units] |
| $v^{\text{decom compact}}_{a,y,v}$         | $\mathbb{Z}_{+}$ | $ (a,y,v) \in \mathcal{D}^{\text{compact investment}}$                                                                         | Number of decommissioned units of asset $a$ commissioned in year $v$ that uses compact investment method at year $y$                  | [units] |
| $v^{\text{inv energy}}_{a,y}$              | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}_y \cap \mathcal{A}^{\text{se}}_y$, $y \in \mathcal{Y}$                                           | Number of invested units of the energy component of the storage asset $a$ that uses energy method at year $y$                         | [units] |
| $v^{\text{decom energy simple}}_{a,y}$     | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{i}}_y \cap \mathcal{A}^{\text{se}}_y$, $y \in \mathcal{Y}$                                           | Number of decommissioned units of the energy component of the storage asset $a$ that uses energy method at year $y$                   | [units] |
| $v^{\text{inv}}_{f,y}$                     | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{ti}}_y$, $y \in \mathcal{Y}$                                                                         | Number of invested units of capacity increment of transport flow $f$ at year $y$                                                      | [units] |
| $v^{\text{decom simple}}_{f,y}$            | $\mathbb{Z}_{+}$ | $f \in \mathcal{F}^{\text{ti}}_y$, $y \in \mathcal{Y}$                                                                         | Number of decommissioned units of capacity increment of transport flow $f$ at year $y$                                                | [units] |
| $v^{\text{intra-storage}}_{a,k_y,b_{k_y}}$ | $\mathbb{R}_{+}$ | $a \in \mathcal{A}^{\text{s}}_y \setminus \mathcal{A}^{\text{ss}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$ | Intra storage level (within a representative period) for storage asset $a$, representative period $k_y$, and timestep block $b_{k_y}$ | [MWh]   |
| $v^{\text{inter-storage}}_{a,p_y}$         | $\mathbb{R}_{+}$ | $a \in \mathcal{A^{\text{ss}}}_y$, $p_y \in \mathcal{P}_y$                                                                     | Inter storage level (between representative periods) for storage asset $a$ and period $p_y$                                           | [MWh]   |
| $v^{\text{is charging}}_{a,k_y,b_{k_y}}$   | $\{0, 1\}$       | $a \in \mathcal{A}^{\text{sb}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$                                    | If an storage asset $a$ is charging or not in representative period $k_y$ and timestep block $b_{k_y}$                                | [-]     |
| $v^{\text{angle}}_{a,k_y,b_{k_y}}$         | $\mathbb{R}$     | $a \in \mathcal{A}^{\text{dc-opf}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$                                | Electricity angle of asset $a$ in representative period $k_y$ and timestep block $b_{k_y}$                                            | [rad]   |
| $v^{\text{units on}}_{a,k_y,b_{k_y}}$      | $\mathbb{Z}_{+}$ | $a \in \mathcal{A}^{\text{uc}}_y$, $k_y \in \mathcal{K}_y$, $b_{k_y} \in \mathcal{B_{k_y}}$                                    | Number of units ON of asset $a$ in representative period $k_y$ and timestep block $b_{k_y}$                                           | [units] |

## [Objective Function](@id math-objective-function)

### Expresssions for the Objective Function

For available units across years, we define the following expresssions:

```math
\begin{aligned}
    v^{\text{available units simple method}}_{a,y} & = p^{\text{initial units}}_{a,y} + \sum_{i \in \{\mathcal{Y}^\text{i}: y - p^{\text{technical lifetime}}_{a} + 1  \le i \le y \}}  v^{\text{inv}}_{a,i} - \sum_{i \in \{\mathcal{Y}: y - p^{\text{technical lifetime}}_{a} + 1  \le i \le y \}} v^{\text{decom simple}}_{a,i} \\
    & \forall a \in \mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}}, \forall y \in \mathcal{Y} \\
    v^{\text{available units compact method}}_{a,y,v} & = p^{\text{initial units}}_{a,y,v} + v^{\text{inv}}_{a,v} - \sum_{i \in \{\mathcal{Y}: v < i \le y\} | (a,i,v) \in \mathcal{D}^{\text{compact investment}}} v^{\text{decom compact}}_{a,i,v}
 \\
    & \forall (a,y,v) \in \mathcal{D}^{\text{compact investment}} \cup \mathcal{D}^{\text{operation}} \\
    v^{\text{available energy units simple method}}_{a,y} & = p^{\text{initial storage units}}_{a,y} + \sum_{i \in \{\mathcal{Y}^\text{i}: y - p^{\text{technical lifetime}}_{a} + 1  \le i \le y \}}  v^{\text{inv energy}}_{a,i} - \sum_{i \in \{\mathcal{Y}: y - p^{\text{technical lifetime}}_{a} + 1  \le i \le y \}} v^{\text{decom energy simple}}_{a,i} \\
    & \forall a \in \mathcal{A}^{\text{se}}_y, \forall y \in \mathcal{Y} \\
    v^{\text{available export units simple method}}_{f,y} & = p^{\text{initial export units}}_{f,y} + \sum_{i \in \{\mathcal{Y}^\text{i}: y - p^{\text{technical lifetime}}_{f} + 1  \le i \le y \}}  v^{\text{inv}}_{f,i} - \sum_{i \in \{\mathcal{Y}: y - p^{\text{technical lifetime}}_{f} + 1  \le i \le y \}} v^{\text{decom simple}}_{f,i} \\
    & \forall f \in \mathcal{F}^{\text{t}}_y, \forall y \in \mathcal{Y} \\
    v^{\text{available import units simple method}}_{f,y} & = p^{\text{initial import units}}_{f,y} + \sum_{i \in \{\mathcal{Y}^\text{i}: y - p^{\text{technical lifetime}}_{f} + 1  \le i \le y \}}  v^{\text{inv}}_{f,i} - \sum_{i \in \{\mathcal{Y}: y - p^{\text{technical lifetime}}_{f} + 1  \le i \le y \}} v^{\text{decom simple}}_{f,i} \\
    & \forall f \in \mathcal{F}^{\text{t}}_y, \forall y \in \mathcal{Y} \\
\end{aligned}
```

In addition, we define the following expressions to determine the available units. This expression takes a few forms depending on whether the asset uses _simple_ or _compact_ investment method.

- If the asset uses _simple_ investment method

```math
\begin{aligned}
    v^{\text{available units}}_{a,y} & = v^{\text{available units simple method}}_{a,y} \quad \forall a \in \mathcal{A}, \forall y \in \mathcal{Y}
\end{aligned}
```

- If the asset uses _compact_ investment method

```math
\begin{aligned}
    v^{\text{available units}}_{a,y} & = \sum_{v \in \mathcal{V} | (a,y,v) \in \mathcal{D}^{\text{compact investment}}} v^{\text{available units compact method}}_{a,y,v} \quad \forall a \in \mathcal{A}, \forall y \in \mathcal{Y}
\end{aligned}
```

- Storage assets with energy method always use _simple_ investment method

```math
\begin{aligned}
    v^{\text{available energy units}}_{a,y} & = v^{\text{available energy units simple method}}_{a,y} \quad \forall a \in \mathcal{A}^{\text{se}}_y, \forall y \in \mathcal{Y}
\end{aligned}
```

- Transport assets always use _simple_ investment method

```math
\begin{aligned}
    v^{\text{available export units}}_{f,y} & = v^{\text{available export units simple method}}_{f,y} \quad \forall f \in \mathcal{F}^{\text{t}}_y, \forall y \in \mathcal{Y} \\
    v^{\text{available import units}}_{f,y} & = v^{\text{available import units simple method}}_{f,y} \quad \forall f \in \mathcal{F}^{\text{t}}_y, \forall y \in \mathcal{Y}
\end{aligned}
```

### Economic Representation for the Objective Function

#### Discounting Factor for Asset Investment Costs

```math
p_{a, y}^{\text{discounting factor asset inv cost}}=\frac{1}{(1+p^{\text{social discount rate}})^{y-p^{\text{discount year}}}}(1-\frac{p_{a, y}^{\text{salvage value}}}{p_{a, y}^{\text{inv cost}}}) \quad \forall a \in \mathcal{A}_y^{\text{i}}, \forall y \in \mathcal{Y}
```

where salvage value is

```math
p^{\text{salvage value}}_{a, y} = p^{\text{annualized inv cost}}_{a, y} \sum_{i=y^{\text{last}}+1}^{y + p^{\text{economic lifetime}}_{a, y} - 1} \frac{1}{(1 + p^{\text{technology-specific discount rate}}_{a, y})^{i - y} } \quad \forall a \in \mathcal{A}_y^{\text{i}}, \forall y \in \mathcal{Y}
```

and where annualized cost is

```math
p^{\text{annualized inv cost}}_{a, y} = \frac{p^{\text{technology-specific discount rate}}_{a, y}}{ (1+p^{\text{technology-specific discount rate}}_{a, y}) \cdot \bigg( 1 - \frac{1}{ (1+p^{\text{technology-specific discount rate}}_{a, y})^{p^{\text{economic lifetime}}_{a, y}} } \bigg) } p^{\text{inv cost}}_{a, y} \quad \forall a \in \mathcal{A}_y^{\text{i}}, \forall y \in \mathcal{Y}
```

#### Discounting Factor for Flow Investment Costs

```math
p_{f, y}^{\text{discounting factor flow inv cost}}=\frac{1}{(1+p^{\text{social discount rate}})^{y-p^{\text{discount year}}}}(1-\frac{p_{f, y}^{\text{salvage value}}}{p_{f, y}^{\text{inv cost}}}) \quad \forall f \in \mathcal{F}_y^{\text{ti}}, \forall y \in \mathcal{Y}
```

where salvage value is

```math
p^{\text{salvage value}}_{f, y} = p^{\text{annualized inv cost}}_{f, y} \sum_{i=y^{\text{last}}+1}^{y + p^{\text{economic lifetime}}_{f, y} - 1} \frac{1}{(1 + p^{\text{technology-specific discount rate}}_{f, y})^{i - y} } \quad \forall f \in \mathcal{F}_y^{\text{ti}}, \forall y \in \mathcal{Y}
```

and where annualized cost is

```math
p^{\text{annualized inv cost}}_{f, y} = \frac{p^{\text{technology-specific discount rate}}_{f, y}}{ (1+p^{\text{technology-specific discount rate}}_{f, y}) \cdot \bigg( 1 - \frac{1}{ (1+p^{\text{technology-specific discount rate}}_{f, y})^{p^{\text{economic lifetime}}_{f, y}} } \bigg) } p^{\text{inv cost}}_{f, y} \quad \forall f \in \mathcal{F}_y^{\text{ti}}, \forall y \in \mathcal{Y}
```

#### Discounting Factor for Operation Costs

```math
p_{y}^{\text{discounting factor operation cost}}= \sum^{\text{next}(y)-1}_{y`=y} \frac{1}{(1+p^{\text{social discount rate}})^{y`-p^{\text{discount year}}}} \quad \forall y \in \mathcal{Y}
```

This definition of the discount factor at year $y$ includes the discounts for the range of years from the milestone year $y$ to the next milestone year $y+1$, i.e., \{$y$, $y$+1, ..., next($y$)-1\}, so the discounts at the non-modeled years are also correctly considered. When $y$=last($y$), only the discount at year $y$ is included.

### Objective Function

```math
\begin{aligned}
\text{{minimize}} \quad & assets\_investment\_cost + assets\_fixed\_cost \\
                        & + flows\_investment\_cost + flows\_fixed\_cost \\
                        & + flows\_variable\_cost + unit\_on\_cost
\end{aligned}
```

Where:

```math
\begin{aligned}
assets\_investment\_cost &= \sum_{y \in \mathcal{Y}} \sum_{a \in \mathcal{A}^{\text{i}}_y } p_{a, y}^{\text{discounting factor asset inv cost}} \cdot p^{\text{inv cost}}_{a,y} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a,y} \\ &+  \sum_{y \in \mathcal{Y}} \sum_{a \in \mathcal{A}^{\text{se}}_y \cap \mathcal{A}^{\text{i}}_y } p_{a, y}^{\text{discounting factor asset inv cost}} \cdotp^{\text{inv cost energy}}_{a,y} \cdot p^{\text{energy capacity}}_{a} \cdot v^{\text{inv energy}}_{a,y}   \\
assets\_fixed\_cost &= \sum_{y \in \mathcal{Y}} \sum_{a \in \mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}} } p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{fixed cost}}_{a,y} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units simple method}}_{a,y} \\
& + \sum_{(a,y,v) \in \mathcal{D}^{\text{compact investment}} \cup \mathcal{D}^{\text{decom units operation mode}} }  p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{fixed cost}}_{a,v} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units compact method}}_{a,y,v} \\
& + \sum_{y \in \mathcal{Y}} \sum_{a \in \mathcal{A}^{\text{se}}_y \cap (\mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}}) } p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{fixed cost energy}}_{a,y} \cdot p^{\text{energy capacity}}_{a} \cdot v^{\text{available energy capacity simple method}}_{a,y} \\
flows\_investment\_cost &= \sum_{y \in \mathcal{Y}} \sum_{f \in \mathcal{F}^{\text{ti}}_y} p_{f, y}^{\text{discounting factor flow inv cost}} \cdot p^{\text{inv cost}}_{f,y} \cdot p^{\text{capacity}}_{f} \cdot v^{\text{inv}}_{f,y} \\
flows\_fixed\_cost &= \frac{1}{2} \sum_{y \in \mathcal{Y}} \sum_{f \in \mathcal{F}^{\text{t}}_y} p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{fixed cost}}_{f,y} \cdot p^{\text{capacity}}_{f} \cdot \left( v^{\text{available export units}}_{f,y} + v^{\text{available import units}}_{f,y} \right) \\
flows\_variable\_cost &= \sum_{y \in \mathcal{Y}} \sum_{f \in \mathcal{F}_y} \sum_{k_y \in \mathcal{K}_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{rp weight}}_{k_y} \cdot p^{\text{variable cost}}_{f,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \\
unit\_on\_cost &= \sum_{y \in \mathcal{Y}} \sum_{a \in \mathcal{A}^{\text{uc}}_y} \sum_{k_y \in \mathcal{K}_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p_{y}^{\text{discounting factor operation cost}} \cdot p^{\text{rp weight}}_{k_y} \cdot p^{\text{units on cost}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{units on}}_{a,k_y,b_{k_y}}
\end{aligned}
```

## [Constraints](@id math-constraints)

### [Capacity Constraints](@id cap-constraints)

#### Maximum Output Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units simple method}}_{a,y}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in (\mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}}) \cap \left(\mathcal{A}^{\text{cv}} \cup \left(\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{sb}}_y \right)  \cup \mathcal{A}^{\text{p}} \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}} \\ \\
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{capacity}}_{a} \cdot \sum_{v \in \mathcal{V} | (a,y,v) \in \mathcal{D}^{\text{compact investment}}} p^{\text{availability profile}}_{a,v,k_y,b_{k_y}} \cdot v^{\text{available units compact method}}_{a,y,v}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in (\mathcal{A}^{\text{compact investment}} \cup \mathcal{A}^{\text{operation}}) \cap \left(\mathcal{A}^{\text{cv}} \cup \left(\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{sb}}_y \right) \cup \mathcal{A}^{\text{p}} \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

Storage assets using the method to avoid charging and discharging simultaneously, i.e., $a \in \mathcal{A}^{\text{sb}}_y$, use the following constraints instead of the previous one:

- Maximum output flows limit for storage assets such that $a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot \left(p^{\text{capacity}}_{a} \cdot p^{\text{init units}}_{a,y} + p^{\text{inv limit}}_{a,y} \right) \cdot \left(1 - v^{\text{is charging}}_{a,k_y,b_{k_y}} \right) \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot \left(p^{\text{init units}}_{a,y} \cdot (1 - v^{\text{is charging}}_{a,k_y,b_{k_y}}) - v^{\text{available units}}_{a,y} \right)
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

!!! info
    The negative sign before the $v^{\text{available units}}_{a,y}$ is because the available units include the $p^{\text{init units}}_{a,y}$ in its calculation.

- Maximum output flows limit for storage assets such that $a \in \mathcal{A}^{\text{sb}}_y \setminus \mathcal{A}^{\text{i}}_y$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{init units}}_{a,y} \cdot \left(1 - v^{\text{is charging}}_{a,k_y,b_{k_y}} \right) \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \setminus \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

#### Maximum Input Flows Limit

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units}}_{a,y}   \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{sb}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

Storage assets using the method to avoid charging and discharging simultaneously, i.e., $a \in \mathcal{A}^{\text{sb}}$, use the following constraints instead of the previous one:

- Maximum input flows limit for storage assets such that $a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot \left(p^{\text{capacity}}_{a} \cdot p^{\text{init units}}_{a,y} + p^{\text{inv limit}}_{a,y} \right)  \cdot v^{\text{is charging}}_{a,k_y,b_{k_y}} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K_y},\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot \left(p^{\text{init units}}_{a,y} \cdot v^{\text{is charging}}_{a,k_y,b_{k_y}} - v^{\text{available units}}_{a,y} \right)  \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \cap \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

!!! info
    The negative sign before the $v^{\text{available units}}_{a,y}$ is because the available units include the $p^{\text{init units}}_{a,y}$ in its calculation.

- Maximum input flows limit for storage assets such that $a \in \mathcal{A}^{\text{sb}}_y \setminus \mathcal{A}^{\text{i}}_y$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{capacity coefficient}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{init units}}_{a,y}  \cdot v^{\text{is charging}}_{a,k_y,b_{k_y}} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{sb}}_y \setminus \mathcal{A}^{\text{i}}_y, \forall k_y \in \mathcal{K_y},\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

#### Lower Limit for Flows that are Associated with Assets

```math
v^{\text{flow}}_{f,k_y,b_{k_y}} \geq 0 \quad \forall y \in \mathcal{Y}, \forall f \in \left( \mathcal{F}^{\text{out}}_{a,y} | a \in \mathcal{A}^{\text{p}} \cup \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{s}} \right) \cup \left(\mathcal{F}^{\text{in}}_{a,y} | a \in \mathcal{A}^{\text{cv}} \cup \mathcal{A}^{\text{s}} \right), \forall k_y \in \mathcal{K}_y, \forall b_{k_y} \in \mathcal{B_{k_y}}
```

### [Unit Commitment Constraints](@id uc-constraints)

Production and conversion assets within the set $\mathcal{A}^{\text{uc}}$ will contain the unit commitment constraints in the model. These constraints are based on the work of [Morales-España et al. (2013)](@ref scientific-refs) and [Morales-España et al. (2014)](@ref scientific-refs).

The current version of the code only incorporates a basic unit commitment version of the constraints (i.e., utilizing only the unit commitment variable $v^{\text{units on}}$). However, upcoming versions will include more detailed constraints, incorporating startup and shutdown variables.

For the unit commitment constraints, we define the following expression for the flow that is above the minimum operating point of the asset:

```math
e^{\text{flow above min}}_{a,k_y,b_{k_y}} = \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{min operating point}}_{a,y} \cdot v^{\text{on}}_{a,k_y,b_{k_y}}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{uc}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Limit to the units on variable

```math
v^{\text{on}}_{a,k_y,b_{k_y}} \leq v^{\text{available units}}_{a,y}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{uc}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B}_{k_y}
```

#### Maximum output flow above the minimum operating point

```math
e^{\text{flow above min}}_{a,y,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot \left(1 - p^{\text{min operating point}}_{a,y} \right) \cdot v^{\text{on}}_{a,k_y,b_{k_y}}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{uc basic}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B}_{k_y}
```

#### Minimum output flow above the minimum operating point

```math
e^{\text{flow above min}}_{a,k_y,b_{k_y}} \geq 0  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{uc basic}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B}_{k_y}
```

### [Ramping Constraints](@id ramp-constraints)

Ramping constraints restrict the rate at which the output flow of a production or conversion asset can change. If the asset is part of the unit commitment set (e.g., $\mathcal{A}^{\text{uc}}_y$), the ramping limits apply to the flow above the minimum output, but if it is not, the ramping limits apply to the total output flow.

Ramping constraints that take into account unit commitment variables are based on the work done by [Damcı-Kurt et. al (2016)](@ref scientific-refs). Also, please note that since the current version of the code only handles the basic unit commitment implementation, the ramping constraints are applied to the assets in the set $\mathcal{A}^{\text{uc basic}}_y$.

!!! info "Duration parameter"
    The following constraints are multiplied by $p^{\text{duration}}_{b_{k_y}}$ on the right-hand side to adjust for the duration of the timesteps since the ramp parameters are defined as rates. This assumption is based on the idea that all timesteps are the same in this section, which simplifies the formulation. However, in a flexible temporal resolution context, this may not hold true, and the duration needs to be the minimum duration of all the outgoing flows at the timestep block $b_{k_y}$. For more information, please visit the concept section on flexible time resolution.

#### Maximum Ramp-Up Rate Limit WITH Unit Commitment Method

```math
e^{\text{flow above min}}_{a,k_y,b_{k_y}} - e^{\text{flow above min}}_{a,k_y,b_{k_y}-1} \leq p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{max ramp up}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{on}}_{a,k_y,b_{k_y}}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \left(\mathcal{A}^{\text{ramp}}_y \cap \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Maximum Ramp-Down Rate Limit WITH Unit Commmitment Method

```math
e^{\text{flow above min}}_{a,k_y,b_{k_y}} - e^{\text{flow above min}}_{a,k_y,b_{k_y}-1} \geq - p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot p^{\text{max ramp down}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{on}}_{a,k_y,b_{k_y}-1}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \left(\mathcal{A}^{\text{ramp}}_y \cap \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Maximum Ramp-Up Rate Limit WITHOUT Unit Commitment Method

```math
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}-1} \leq p^{\text{max ramp up}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units simple method}}_{a,y}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in  (\mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}}) \cap\left(\mathcal{A}^{\text{ramp}}_y \setminus \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}} \\
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}-1} \leq p^{\text{max ramp up}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot  \sum_{v \in \mathcal{V} | (a,y,v) \in \mathcal{D}^{\text{compact investment}}} p^{\text{availability profile}}_{a,v,k_y,b_{k_y}} \cdot v^{\text{available units compact method}}_{a,y,v}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in  (\mathcal{A}^{\text{compact investment}} \cup \mathcal{A}^{\text{operation}}) \cap\left(\mathcal{A}^{\text{ramp}}_y \setminus \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Maximum Ramp-Down Rate Limit WITHOUT Unit Commitment Method

```math
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}-1} \geq - p^{\text{max ramp down}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot p^{\text{availability profile}}_{a,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot v^{\text{available units simple method}}_{a,y}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in  (\mathcal{A}^{\text{simple investment}} \cup \mathcal{A}^{\text{operation}}) \cap\left(\mathcal{A}^{\text{ramp}}_y \setminus \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}} \\
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}-1} \geq - p^{\text{max ramp down}}_{a,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot p^{\text{capacity}}_{a} \cdot  \sum_{v \in \mathcal{V} | (a,y,v) \in \mathcal{D}^{\text{compact investment}}} p^{\text{availability profile}}_{a,v,k_y,b_{k_y}} \cdot v^{\text{available units compact method}}_{a,y,v}  \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in  (\mathcal{A}^{\text{compact investment}} \cup \mathcal{A}^{\text{operation}}) \cap\left(\mathcal{A}^{\text{ramp}}_y \setminus \mathcal{A}^{\text{uc basic}}_y \right), \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

### [DC Power Flow Constraints](@id dc-opf-constraints)

For a flow $f$ connecting assets $a^{\text{from}}$ and $a^{\text{to}}$, which belongs to the set $\mathcal{F}^{\text{dc-opf}}_y$, the power flow constraints utilize the following equations:

```math
\begin{aligned}
v^{\text{flow}}_{f,k_y,b_{k_y}} = \frac{p^{\text{power system base}}}{p^{\text{reactance}}_{f,y}} \cdot (v^{\text{angle}}_{a^{\text{from}},k_y,b_{k_y}} - v^{\text{angle}}_{a^{\text{to}},k_y,b_{k_y}}) \quad \forall y \in \mathcal{Y}, \forall f(a^{\text{from}},a^{\text{to}}) \in \mathcal{F}^{\text{dc-opf}}_y, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

### Constraints for Energy Consumer Assets

#### Balance Constraint for Consumers

The balance constraint sense depends on the method selected in the asset file's parameter [`consumer_balance_sense`](@ref schemas). The default value is $=$, but the user can choose $\geq$ as an option.

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} \left\{\begin{array}{l} = \\ \geq \end{array}\right\} p^{\text{demand profile}}_{a,k_y,b_{k_y}} \cdot p^{\text{peak demand}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{c}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

### Constraints for Energy Storage Assets

There are two types of constraints for energy storage assets: intra-temporal and inter-temporal. Intra-temporal constraints impose limits inside a representative period, while inter-temporal constraints combine information from several representative periods (e.g., to model seasonal storage). For more information on this topic, refer to the [concepts section](@ref storage-modeling) or [Tejada-Arango et al. (2018)](@ref scientific-refs) and [Tejada-Arango et al. (2019)](@ref scientific-refs).

In addition, we define the following expression to determine the energy investment limit of the storage assets. This expression takes two different forms depending on whether the storage asset belongs to the set $\mathcal{A}^{\text{se}}$ or not.

- Investment energy method:

```math
e^{\text{available energy inv limit}}_{a,y} = p^{\text{energy capacity}}_a \cdot v^{\text{available energy units}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{i}} \cap \mathcal{A}^{\text{se}}_y
```

- Fixed energy-to-power ratio method:

```math
e^{\text{available energy inv limit}}_{a,y} = p^{\text{capacity storage energy}}_a \cdot p^{\text{initial storage units}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in (\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{se}}_y)
```

```math
\begin{aligned}
e^{\text{available energy inv limit}}_{a,y}
& = p^{\text{capacity storage energy}}_a \cdot p^{\text{initial storage units}}_{a,y} \\
& + p^{\text{energy to power ratio}}_{a,y} \cdot p^{\text{capacity}}_a \cdot v^{\text{available units}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{i}} \cap (\mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{se}}_y)
\end{aligned}
```

#### [Intra-temporal Constraint for Storage Balance](@id intra-storage-balance)

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k_y,b_{k_y}} = \left(1 - p^{\text{storage loss from stored energy}}_{a, y}\right)^{p^{\text{duration}}_{b_{k_y}}}
 \cdot  v^{\text{intra-storage}}_{a,k_y,b_{k_y}-1}  + p^{\text{inflows}}_{a,k_y,b_{k_y}} + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

#### Intra-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k_y,b_{k_y}} \leq p^{\text{max intra level}}_{a,k_y,b_{k_y}} \cdot e^{\text{available energy inv limit}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Intra-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{intra-storage}}_{a,k_y,b_{k_y}} \geq p^{\text{min intra level}}_{a,k_y,b_{k_y}} \cdot e^{\text{available energy inv limit}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
```

#### Intra-temporal Cycling Constraint

The cycling constraint for the intra-temporal constraints links the first timestep block ($b^{\text{first}}_{k_y}$) and the last one ($b^{\text{last}}_{k_y}$) in each representative period. The parameter $p^{\text{init storage level}}_{a,y}$ determines the considered equations in the model for this constraint:

- If parameter $p^{\text{init storage level}}_{a,y}$ is not defined, the intra-storage level of the last timestep block ($b^{\text{last}}_{k_y}$) is used as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance).

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k_y,b^{\text{first}}_{k_y}} = v^{\text{intra-storage}}_{a,k_y,b^{\text{last}}_{k_y}}  + p^{\text{inflows}}_{a,k_y,b^{\text{first}}_{k_y}} + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b^{\text{first}}_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b^{\text{first}}_{k_y}} \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y
\end{aligned}
```

- If parameter $p^{\text{init storage level}}_{a,y}$ is defined, we use it as the initial value for the first timestep block in the [intra-temporal constraint for the storage balance](@ref intra-storage-balance). In addition, the intra-storage level of the last timestep block ($b^{\text{last}}_{k_y}$) in each representative period must be greater than this initial value.

```math
\begin{aligned}
v^{\text{intra-storage}}_{a,k_y,b^{\text{first}}_{k_y}} = p^{\text{init storage level}}_{a,y}  + p^{\text{inflows}}_{a,k_y,b^{\text{first}}_{k_y}} + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b^{\text{first}}_{k_y}} - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \cdot p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b^{\text{first}}_{k_y}} \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y
\end{aligned}
```

```math
v^{\text{intra-storage}}_{a,k_y,b^{\text{first}}_{k_y}} \geq p^{\text{init storage level}}_{a,y} \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{s}} \setminus \mathcal{A}^{\text{ss}}, \forall k_y \in \mathcal{K}_y
```

#### [Inter-temporal Constraint for Storage Balance](@id inter-storage-balance)

This constraint allows us to consider the storage seasonality throughout the model's timeframe (e.g., a year). The parameter $p^{\text{map}}_{p_y,k_y}$ determines how much of the representative period $k_y$ is in the period $p_y$, and you can use a clustering technique to calculate it. For _TulipaEnergyModel.jl_, we recommend using [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl) to compute the clusters for the representative periods and their map.

For the sake of simplicity, we show the constraint assuming the inter-storage level between two consecutive periods $p_y$; however, _TulipaEnergyModel.jl_ can handle more flexible period block definition through the timeframe definition in the model using the information in the timeframe partitions file, see [schemas](@ref schemas).

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p_y} = & \left(1 - p^{\text{storage loss from stored energy}}_{a, y}\right)^{\sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}}}
 \cdot v^{\text{inter-storage}}_{a,p_y-1} + \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{inflows}}_{a,k_y,b_{k_y}} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}}
\\ \\ & \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}, \forall p_y \in \mathcal{P}_y
\end{aligned}
```

#### Inter-temporal Constraint for Maximum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p_y} \leq p^{\text{max inter level}}_{a,p_y} \cdot e^{\text{available energy inv limit}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}, \forall p_y \in \mathcal{P}_y
```

#### Inter-temporal Constraint for Minimum Storage Level Limit

```math
v^{\text{inter-storage}}_{a,p_y} \geq p^{\text{min inter level}}_{a,p_y} \cdot e^{\text{available energy inv limit}}_{a,y} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}, \forall p_y \in \mathcal{P}_y
```

#### Inter-temporal Cycling Constraint

The cycling constraint for the inter-temporal constraints links the first-period block ($p^{\text{first}}_y$) and the last one ($p^{\text{last}}_y$) in the timeframe. The parameter $p^{\text{init storage level}}_{a,y}$ determines the considered equations in the model for this constraint:

- If parameter $p^{\text{init storage level}}_{a,y}$ is not defined, the inter-storage level of the last period block ($p^{\text{last}}_y$) is used as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance).

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}_y} = & v^{\text{inter-storage}}_{a,p^{\text{last}}_y} + \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{inflows}}_{a,k_y,b_{k_y}} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}}
\\ \\ & \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}
\end{aligned}
```

- If parameter $p^{\text{init storage level}}_{a,y}$ is defined, we use it as the initial value for the first-period block in the [inter-temporal constraint for the storage balance](@ref inter-storage-balance). In addition, the inter-storage level of the last period block ($p^{\text{last}}_y$) in the timeframe must be greater than this initial value.

```math
\begin{aligned}
v^{\text{inter-storage}}_{a,p^{\text{first}}_y} = & p^{\text{init storage level}}_{a,y} + \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{inflows}}_{a,k_y,b_{k_y}} \\
& + \sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \\
& - \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{1}{p^{\text{eff}}_{f,y}} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p^{\text{first}}_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_{k_y}} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}}
\\ \\ & \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}
\end{aligned}
```

```math
v^{\text{inter-storage}}_{a,p^{\text{last}}_y} \geq p^{\text{init storage level}}_{a,y} \quad
\\ \\ \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{ss}}
```

### Constraints for Energy Hub Assets

#### Balance Constraint for Hubs

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}} = \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} v^{\text{flow}}_{f,k_y,b_{k_y}}
\quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{h}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

### Constraints for Energy Conversion Assets

#### Balance Constraint for Conversion Assets

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{in}}_{a,y}} p^{\text{eff}}_{f,y} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} = \sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \frac{v^{\text{flow}}_{f,k_y,b_{k_y}}}{p^{\text{eff}}_{f,y}}
\quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{cv}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

### Constraints for Transport Assets

#### Maximum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k_y,b_{k_y}} \leq p^{\text{availability profile}}_{f,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{f} \cdot v^{\text{available export units}}_{f,y}  \quad \forall y \in \mathcal{Y}, \forall f \in \mathcal{F}^{\text{t}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

#### Minimum Transport Flow Limit

```math
\begin{aligned}
v^{\text{flow}}_{f,k_y,b_{k_y}} \geq - p^{\text{availability profile}}_{f,y,k_y,b_{k_y}} \cdot p^{\text{capacity}}_{f} \cdot v^{\text{available import units}}_{f,y}  \quad \forall y \in \mathcal{Y}, \forall f \in \mathcal{F}^{\text{t}}, \forall k_y \in \mathcal{K}_y,\forall b_{k_y} \in \mathcal{B_{k_y}}
\end{aligned}
```

### Constraints for Investments

#### Maximum Investment Limit for Assets

```math
v^{\text{inv}}_{a,y} \leq \frac{p^{\text{inv limit}}_{a,y}}{p^{\text{capacity}}_{a}} \quad \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{i}}_y
```

If the parameter `investment_integer` is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

#### Maximum Energy Investment Limit for Assets

```math
v^{\text{inv energy}}_{a,y} \leq \frac{p^{\text{inv limit energy}}_{a,y}}{p^{\text{energy capacity}}_{a}} \quad \forall y \in \mathcal{Y},  \forall a \in \mathcal{A}^{\text{i}}_y \cap \mathcal{A}^{\text{se}}_y
```

If the parameter `investment_integer_storage_energy` is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

#### Maximum Investment Limit for Flows

```math
v^{\text{inv}}_{f,y} \leq \frac{p^{\text{inv limit}}_{f,y}}{p^{\text{capacity}}_{f}} \quad \forall y \in \mathcal{Y}, \forall f \in \mathcal{F}^{\text{ti}}_y
```

If the parameter `investment_integer` is set to true, then the right-hand side of this constraint uses a least integer function (floor function) to guarantee that the limit is integer.

### [Inter-temporal Energy Constraints](@id inter-temporal-energy-constraints)

These constraints allow us to consider a maximum or minimum energy limit for an asset throughout the model's timeframe (e.g., a year). It uses the same principle explained in the [inter-temporal constraint for storage balance](@ref inter-storage-balance) and in the [Storage Modeling](@ref storage-modeling) section.

#### Maximum Outgoing Energy During the Timeframe

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \leq  p^{\text{max inter profile}}_{a,p_y} \cdot p^{\text{max energy}}_{a,y}
\\ \\ & \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{max e}}, \forall p_y \in \mathcal{P}_y
\end{aligned}
```

#### Minimum Outgoing Energy During the Timeframe

```math
\begin{aligned}
\sum_{f \in \mathcal{F}^{\text{out}}_{a,y}} \sum_{k_y \in \mathcal{K}_y} p^{\text{map}}_{p_y,k_y} \sum_{b_{k_y} \in \mathcal{B_{k_y}}} p^{\text{duration}}_{b_k} \cdot v^{\text{flow}}_{f,k_y,b_{k_y}} \geq  p^{\text{min inter profile}}_{a,p_y} \cdot p^{\text{min energy}}_{a,y}
\\ \\ & \forall y \in \mathcal{Y}, \forall a \in \mathcal{A}^{\text{min e}}, \forall p_y \in \mathcal{P}_y
\end{aligned}
```

### [Constraints for Groups](@id group-constraints)

The following constraints aggregate variables of different assets depending on the method that applies to the group.

#### [Investment Limits of a Group](@id investment-group-constraints)

These constraints apply to assets in a group using the investment method $\mathcal{G}^{\text{ai}}_y$. They help impose an investment potential of a spatial area commonly shared by several assets that can be invested there.

!!! info
    These constraints are applied to the investments each year. The model does not yet have investment limits to a group's available invested capacity.

##### Minimum Investment Limit of a Group

```math
\begin{aligned}
\sum_{a \in \mathcal{A}^{\text{i}}_y | p^{\text{group}}_{a} = g} p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a,y} \geq  p^{\text{min invest limit}}_{g,y}
\\ \\ & \forall y \in \mathcal{Y}, \forall g \in \mathcal{G}^{\text{ai}}_y
\end{aligned}
```

##### Maximum Investment Limit of a Group

```math
\begin{aligned}
\sum_{a \in \mathcal{A}^{\text{i}}_y | p^{\text{group}}_{a} = g} p^{\text{capacity}}_{a} \cdot v^{\text{inv}}_{a,y} \leq  p^{\text{max invest limit}}_{g,y}
\\ \\ & \forall y \in \mathcal{Y}, \forall g \in \mathcal{G}^{\text{ai}}_y
\end{aligned}
```
