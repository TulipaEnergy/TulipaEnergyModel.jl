# [Mathematical Formulation](@id math-formulation)

This section shows the mathematical formulation of the model.

## [Sets](@id math-sets)

Name|Description|Elements
 ---|---|---:
$\mathcal{A}$           | Energy assets                         | $a \in \mathcal{A}$
$\mathcal{A_c}$         | Consumer energy assets                | $\mathcal{A_c} \subseteq \mathcal{A}$
$\mathcal{A_p}$         | Producer energy assets                | $\mathcal{A_p} \subseteq \mathcal{A}$
$\mathcal{A_i}$         | Energy assets with investment method  | $\mathcal{A_i} \subseteq \mathcal{A}$
$\mathcal{A_b}$         | Energy assets with balance method     | $\mathcal{A_b} \subseteq \mathcal{A}$
$\mathcal{RP}$          | Representative periods                | $rp \in \mathcal{RP}$
$\mathcal{K}$           | Time steps within the $rp$            | $k \in \mathcal{K}$
$\mathcal{F}$           | Flow connections between two assets   | $f \in \mathcal{F}$
$\mathcal{F_{rec}}(a)$  | Set of flows with receiving asset $a$ | $\mathcal{F_{rec}}(a) \subseteq \mathcal{F}$
$\mathcal{F_{snd}}(a)$  | Set of flows with sending asset $a$   | $\mathcal{F_{snd}}(a) \subseteq \mathcal{F}$

## [Parameters](@id math-parameters)

Name|Description|Units
 ---|---|---
$p^{investment\_cost}_{a}$ | Investment cost  of asset units      | [kEUR/MW/year]
$p^{variable\_cost}_{a}$   | Variable cost of asset units         | [kEUR/MWh]
$p^{unit\_capacity}_{a}$   | Capacity of asset units              | [MW]
$p^{rp\_weight}_{rp}$      | Representative period weight         | [h]
$p^{profile}_{a,rp, k}$    | Asset production/consumption profile | [p.u.]
$p^{peak\_demand}_{a}$     | Peak demand                          | [MW]
$p^{init\_capacity}_{a}$   | initial capacity of asset units      | [MW]

## [Variables](@id math-variables)

Name|Description|Units
 ---|---|---
$v^{flow}_{f,rp,k} \in \mathbb{R}$     | Flow between two assets         |[MW]
$v^{investment}_{a} \in \mathbb{Z^{+}}$| Number of installed asset units |[units]

## [Objective Function](@id math-objective-function)

Objective function:

```math
\text{{minimize}} \quad investment\_cost + variable\_cost
```

Where:

```math
\begin{aligned}
investment\_cost &= \sum_{a \in \mathcal{Ai}} p^{investment\_cost}_a \cdot p^{unit\_capacity}_a \cdot v^{investment}_a \\
variable\_cost &= \sum_{a \in \mathcal{Ap}} \sum_{f \in \mathcal{F_{snd}}(a)} \sum_{rp \in \mathcal{RP}} \sum_{k \in \mathcal{K}} p^{rp\_weight}_{rp} \cdot p^{variable\_cost}_a \cdot v^{flow}_{f,rp,k}
\end{aligned}
```

## [Constraints](@id math-constraints)

### Balance Constraint

```math
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F_{snd}}(a)} v^{flow}_{f,rp,k} = p^{profile}_{a,rp,k} \cdot p^{peak\_demand}_{a} \quad \forall a \in \mathcal{A_b}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

### Upper Bound Constraint for Flows

```math
\begin{aligned}
v^{flow}_{f,rp,k} \leq p^{profile}_{a,rp,k} \cdot \left(p^{init\_capacity}_{a} + p^{unit\_capacity}_a \cdot v^{investment}_a \right)  \quad \forall a \in \mathcal{Ap}, \forall f \in \mathcal{F_{snd}}(a), \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
```

### Lower Bound Constraint for Flows

```math
v^{flow}_{f,rp,k} \geq 0 \quad \forall f \in \mathcal{F}, \forall rp \in \mathcal{RP}, \forall k \in \mathcal{k}
```
