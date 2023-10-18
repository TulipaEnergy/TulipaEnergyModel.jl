# [Mathematical Formulation](@id math-formulation)

This section shows the mathematical formulation of the model.\
The full mathematical formulation is also freely available in the [preprint](https://arxiv.org/abs/2309.07711).

## [Sets](@id math-sets)

NOTE: Asset types are mutually exclusive.
Name|Description|Elements
 ---|---|---:
$\mathcal{A}$           | Energy assets                           | $a \in \mathcal{A}$
$\mathcal{A}_c$         | Consumer energy assets                  | $\mathcal{A}_c   \subseteq \mathcal{A}$
$\mathcal{A}_p$         | Producer energy assets                  | $\mathcal{A}_p   \subseteq \mathcal{A}$
$\mathcal{A}_s$         | Storage energy assets                   | $\mathcal{A}_s   \subseteq \mathcal{A}$
$\mathcal{A}_h$         | Hub energy assets (e.g., transshipment) | $\mathcal{A}_h   \subseteq \mathcal{A}$
$\mathcal{A}_{cv}$      | Conversion energy assets                | $\mathcal{A}_{cv}\subseteq \mathcal{A}$
$\mathcal{A}_i$         | Energy assets with investment method    | $\mathcal{A}_i   \subseteq \mathcal{A}$
$\mathcal{F}$           | Flow connections between two assets     | $f \in \mathcal{F}$
$\mathcal{F}_t$         | Transport flow between two assets       | $\mathcal{F}_t   \subseteq \mathcal{F}$
$\mathcal{F}_i$         | Transport flow with investment method   | $\mathcal{F}_i   \subseteq \mathcal{F}_t$
$\mathcal{F}_{in}(a)$   | Set of flows going into asset $a$       | $\mathcal{F}_{in}(a) \subseteq \mathcal{F}$
$\mathcal{F}_{out}(a)$  | Set of flows going out of asset $a$     | $\mathcal{F}_{out}(a) \subseteq \mathcal{F}$
$\mathcal{RP}$          | Representative periods                  | $rp \in \mathcal{RP}$
$\mathcal{K}$           | Time steps within the $rp$              | $k \in \mathcal{K}$

## [Parameters](@id math-parameters)

Name|Domain|Description|Units
 ---|---|---|---
$p^{investment\_cost}_{a}$ | $\mathcal{A}_i$    | Investment cost  of asset units         | [kEUR/MW/year]
$p^{unit\_capacity}_{a}$   | $\mathcal{A}$      | Capacity of asset units                 | [MW]
$p^{peak\_demand}_{a}$     | $\mathcal{A}_c$    | Peak demand                             | [MW]
$p^{init\_capacity}_{a}$   | $\mathcal{A}$      | Initial capacity of asset units         | [MW]
$p^{investment\_cost}_{f}$ | $\mathcal{F}_i$    | Investment cost  of flow connections    | [kEUR/MW/year]
$p^{variable\_cost}_{f}$   | $\mathcal{F}$      | Variable cost of flow connections       | [kEUR/MWh]
$p^{unit\_capacity}_{f}$   | $\mathcal{F}$      | Capacity of flow connections            | [MW]
$p^{init\_capacity}_{f}$   | $\mathcal{F}$      | Initial capacity of flow connections    | [MW]
$p^{rp\_weight}_{rp}$      | $\mathcal{RP}$     | Representative period weight            | [h]
$p^{profile}_{a,rp,k}$     | $\mathcal{A,RP,K}$ | Asset profile                           | [p.u.]
$p^{profile}_{f,rp,k}$     | $\mathcal{F,RP,K}$ | Flow connections profile                | [p.u.]
$p^{energy2power\_ratio}_a$| $\mathcal{A}_s$    | Energy to power ratio                   | [h]
$p^{eff\_out}_a$           | $\mathcal{A}_s$    | Discharge efficiency                    | [p.u.]
$p^{eff\_in}_a$            | $\mathcal{A}_s$    | Charge efficiency                       | [p.u.]
$p^{eff\_out}_f$           | $\mathcal{F}$      | Flow efficiency out                     | [p.u.]
$p^{eff\_in}_f$            | $\mathcal{F}$      | Flow efficiency in                      | [p.u.]

## [Variables](@id math-variables)

Name|Domain|Description|Units
 ---|---|---|---
$v^{flow}_{f,rp,k}  \in \mathbb{R}$    | $\mathcal{F,RP,K}$    | Flow between two assets                      |[MW]
$v^{investment}_{a} \in \mathbb{Z}^{+}$| $\mathcal{A}_i$       | Number of installed asset units              |[units]
$v^{investment}_{f} \in \mathbb{Z}^{+}$| $\mathcal{F}_i$       | Number of installed units between two assets |[units]
$s^{level}_{a,rp,k} \in \mathbb{R}$    | $\mathcal{A_s,RP,K}$  | Storage level                                |[MWh]

**Missing:**

- `s`

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
assets\_investment\_cost &= \sum_{a \in \mathcal{Ai}} p^{investment\_cost}_a \cdot p^{unit\_capacity}_a \cdot v^{investment}_a \\
flows\_investment\_cost &= \sum_{f \in \mathcal{Fi}} p^{investment\_cost}_f \cdot p^{unit\_capacity}_f \cdot v^{investment}_f \\
flows\_variable\_cost &= \sum_{f \in \mathcal{F}} \sum_{rp \in \mathcal{RP}} \sum_{k \in \mathcal{K}} p^{rp\_weight}_{rp} \cdot p^{variable\_cost}_f \cdot v^{flow}_{f,rp,k}
\end{aligned}
```

## [Constraints](@id math-constraints)

### Balancing Contraints for Asset Type

#### Constraints for Consumers Energy Assets $\mathcal{A}_c$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}_{in}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F}_{out}(a)} v^{flow}_{f,rp,k} \left\{\begin{array}{l} = \\ \geqslant \\ \leqslant \end{array}\right\} p^{profile}_{a,rp,k} \cdot p^{peak\_demand}_{a} \quad \forall a \in \mathcal{A}_c, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Constraints for Storage Energy Assets $\mathcal{A}_s$

```math
\begin{aligned}
s_{a,rp,k}^{level} = s_{a,rp,k-1}^{level} + p_{a,rp,k}^{inflow} + p^{eff\_in}_a \cdot \sum_{f \in \mathcal{F}_{in}(a)} v^{flow}_{f,rp,k} - \frac{1}{p^{eff\_out}_a} \cdot \sum_{f \in \mathcal{F}_{out}(a)} v^{flow}_{f,rp,k} \quad \forall a \in \mathcal{A}_s, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Constraints for Hub Energy Assets $\mathcal{A}_h$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}_{in}(a)} v^{flow}_{f,rp,k} = \sum_{f \in \mathcal{F}_{out}(a)} v^{flow}_{f,rp,k} \quad \forall a \in \mathcal{A}_h, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Constraints for Conversion Energy Assets $\mathcal{A}_{cv}$

```math
\begin{aligned}
\sum_{f \in \mathcal{F}_{in}(a)} p^{eff\_in}_f \cdot {v^{flow}_{f,rp,k}} = \sum_{f \in \mathcal{F}_{out}(a)} \frac{v^{flow}_{f,rp,k}}{p^{eff\_out}_f}  \quad \forall a \in \mathcal{A}_{cv}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

### Constraints that Define Bounds of Flows Related to Energy Assets $\mathcal{A}$

#### Contraint for the Overall Output Flows from an Asset

```math
\begin{aligned}
\sum_{f \in \mathcal{F}_{out}(a)} v^{flow}_{f,rp,k} \leq p^{profile}_{a,rp,k} \cdot \left(p^{init\_capacity}_{a} + p^{unit\_capacity}_a \cdot v^{investment}_a \right)  \quad \forall a \in \mathcal{A}_{cv} \cup \mathcal{A_{s}} \cup \mathcal{A_{p}}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Contraint for the Overall Input Flows from an Asset

```math
\begin{aligned}
\sum_{f \in \mathcal{F}_{in}(a)} v^{flow}_{f,rp,k} \leq p^{profile}_{a,rp,k} \cdot \left(p^{init\_capacity}_{a} + p^{unit\_capacity}_a \cdot v^{investment}_a \right)  \quad \forall a \in \mathcal{A_{s}}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Upper Bound Constraint for Associated with Asset

```math
\begin{aligned}
v^{flow}_{f,rp,k} \leq p^{profile}_{a,rp,k} \cdot \left(p^{init\_capacity}_{a} + p^{unit\_capacity}_a \cdot v^{investment}_a \right)  \quad \forall a \notin \mathcal{A}_h, \forall f \in \mathcal{F}_{out}(a), \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Lower Bound Constraint Flows Associated with Asset

```math
v^{flow}_{f,rp,k} \geq 0 \quad \forall f \notin \mathcal{F}_t, \forall rp \in \mathcal{RP}, \forall k \in \mathcal{k}
```

### Constraints that Define Bounds for a Transport Flow $\mathcal{F}_t$

#### Upper Bound Constraint for Transport Flows

```math
\begin{aligned}
v^{flow}_{f,rp,k} \leq p^{profile}_{f,rp,k} \cdot \left(p^{init\_capacity}_{f} + p^{unit\_capacity}_f \cdot v^{investment}_f \right)  \quad \forall f \in \mathcal{F}_t, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

#### Lower Bound Constraint for Transport Flows

```math
\begin{aligned}
v^{flow}_{f,rp,k} \geq p^{profile}_{f,rp,k} \cdot \left(p^{init\_capacity}_{f} + p^{unit\_capacity}_f \cdot v^{investment}_f \right)  \quad \forall f \in \mathcal{F}_t, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

### Extra Constraints for Energy Storage Assets $\mathcal{A}_s$

#### Upper and Lower Bound Constraints for Storage Level

```math
0 \leq s_{a,rp,k}^{level} \leq p^{init\_storage\_capacity}_{a} + p^{energy2power\_ratio}_a \cdot p^{unit\_capacity}_a \cdot v^{investment}_a \quad \forall a \in \mathcal{A}_s, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
```
