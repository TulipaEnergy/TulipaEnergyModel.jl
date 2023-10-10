# [Mathematical Formulation](@id math-formulation)

This section shows the mathematical formulation of the model.\
The full mathematical formulation is also freely available in the [preprint](https://arxiv.org/abs/2309.07711).

## [Sets](@id math-sets)

Name|Description|Elements
 ---|---|---:
$\mathcal{A}$           | Energy assets                         | $a \in \mathcal{A}$
$\mathcal{A_c}$         | Consumer energy assets                | $\mathcal{A_c}   \subseteq \mathcal{A}$
$\mathcal{A_p}$         | Producer energy assets                | $\mathcal{A_p}   \subseteq \mathcal{A}$
$\mathcal{A_s}$         | Storage energy assets                 | $\mathcal{A_s}   \subseteq \mathcal{A}$
$\mathcal{A_t}$         | Transhipment energy assets            | $\mathcal{A_t}   \subseteq \mathcal{A}$
$\mathcal{A_{cv}}$      | Conversion energy assets              | $\mathcal{A_{cv}}\subseteq \mathcal{A}$
$\mathcal{A_i}$         | Energy assets with investment method  | $\mathcal{A_i}   \subseteq \mathcal{A}$
$\mathcal{F}$           | Flow connections between two assets   | $f \in \mathcal{F}$
$\mathcal{F_t}$         | Transport flow between two assets     | $\mathcal{F_t}   \subseteq \mathcal{F}$
$\mathcal{F_i}$         | Transport flow with investment method | $\mathcal{F_i}   \subseteq \mathcal{F_t}$
$\mathcal{F_{rec}}(a)$  | Set of flows with receiving asset $a$ | $\mathcal{F_{rec}}(a) \subseteq \mathcal{F}$
$\mathcal{F_{snd}}(a)$  | Set of flows with sending asset $a$   | $\mathcal{F_{snd}}(a) \subseteq \mathcal{F}$
$\mathcal{RP}$          | Representative periods                | $rp \in \mathcal{RP}$
$\mathcal{K}$           | Time steps within the $rp$            | $k \in \mathcal{K}$

## [Parameters](@id math-parameters)

Name|Description|Units
 ---|---|---
$p^{investment\_cost}_{a}$ | Investment cost  of asset units      | [kEUR/MW/year]
$p^{unit\_capacity}_{a}$   | Capacity of asset units              | [MW]
$p^{peak\_demand}_{a}$     | Peak demand                          | [MW]
$p^{init\_capacity}_{a}$   | initial capacity of asset units      | [MW]
$p^{investment\_cost}_{f}$ | Investment cost  of flow connections | [kEUR/MW/year]
$p^{variable\_cost}_{f}$   | Variable cost of flow connections    | [kEUR/MWh]
$p^{unit\_capacity}_{f}$   | Capacity of flow connections         | [MW]
$p^{init\_capacity}_{f}$   | initial capacity of flow connections | [MW]
$p^{rp\_weight}_{rp}$      | Representative period weight         | [h]
$p^{profile}_{a,rp,k}$     | Asset profile                        | [p.u.]
$p^{profile}_{f,rp,k}$     | Flow connections profile             | [p.u.]

## [Variables](@id math-variables)

Name|Description|Units
 ---|---|---
$v^{flow}_{f,rp,k} \in \mathbb{R}$     | Flow between two assets                      |[MW]
$v^{investment}_{a} \in \mathbb{Z^{+}}$| Number of installed asset units              |[units]
$v^{investment}_{f} \in \mathbb{Z^{+}}$| Number of installed units between two assets |[units]

## [Objective Function](@id math-objective-function)

Objective function:

$$
\begin{aligned}
\text{{minimize}} \quad & assets\_investment\_cost + flows\_investment\_cost \\
                        & + flows\_variable\_cost
\end{aligned}
$$

Where:

$$
\begin{aligned}
assets\_investment\_cost &= \sum_{a \in \mathcal{Ai}} p^{investment\_cost}_a \cdot p^{unit\_capacity}_a \cdot v^{investment}_a \\
flows\_investment\_cost &= \sum_{f \in \mathcal{Fi}} p^{investment\_cost}_f \cdot p^{unit\_capacity}_f \cdot v^{investment}_f \\
flows\_variable\_cost &= \sum_{f \in \mathcal{F}} \sum_{rp \in \mathcal{RP}} \sum_{k \in \mathcal{K}} p^{rp\_weight}_{rp} \cdot p^{variable\_cost}_f \cdot v^{flow}_{f,rp,k}
\end{aligned}
$$

## [Constraints](@id math-constraints)

### Constraints for Consumers Energy Assets $\mathcal{A_c}$

- Balance constraint:

$$
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F_{snd}}(a)} v^{flow}_{f,rp,k} = p^{profile}_{a,rp,k} \cdot p^{peak\_demand}_{a} \quad \forall a \in \mathcal{A_c}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Constraints for Producers Energy Assets $\mathcal{A_p}$

$$
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F_{snd}}(a)} v^{flow}_{f,rp,k} = p^{profile}_{a,rp,k} \cdot p^{peak\_demand}_{a} \quad \forall a \in \mathcal{A_p}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Constraints for Storage Energy Assets $\mathcal{A_s}$

$$
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F_{snd}}(a)} v^{flow}_{f,rp,k} = p^{profile}_{a,rp,k} \cdot p^{peak\_demand}_{a} \quad \forall a \in \mathcal{A_s}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Constraints for Transhipment Energy Assets $\mathcal{A_t}$

- Balance constraint:

$$
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} - \sum_{f \in \mathcal{F_{snd}}(a)} v^{flow}_{f,rp,k} = 0 \quad \forall a \in \mathcal{A_t}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Constraints for Conversion Energy Assets $\mathcal{A_{cv}}$

$$
\begin{aligned}
\sum_{f \in \mathcal{F_{rec}}(a)} v^{flow}_{f,rp,k} = \sum_{f \in \mathcal{F_{snd}}(a)} \frac{v^{flow}_{f,rp,k}}{\eta_{f???}}  \quad \forall a \in \mathcal{A_{cv}}, \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Upper Bound Constraint for Flows

$$
\begin{aligned}
v^{flow}_{f,rp,k} \leq p^{profile}_{a,rp,k} \cdot \left(p^{init\_capacity}_{a} + p^{unit\_capacity}_a \cdot v^{investment}_a \right)  \quad \forall a \in \mathcal{Ap}, \forall f \in \mathcal{F_{snd}}(a), \forall rp \in \mathcal{RP},\forall k \in \mathcal{K}
\end{aligned}
$$

### Lower Bound Constraint for Flows

$$
v^{flow}_{f,rp,k} \geq 0 \quad \forall f \in \mathcal{F}, \forall rp \in \mathcal{RP}, \forall k \in \mathcal{k}
$$
