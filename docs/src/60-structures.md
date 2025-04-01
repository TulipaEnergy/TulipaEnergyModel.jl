# [Model Structures](@id structures)

```@contents
Pages = ["60-structures.md"]
Depth = [2, 3]
```

The list of relevant structures used in this package are listed below:

## [EnergyProblem](@id energy-problem)

The `EnergyProblem` structure is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

### Fields

- `db_connection`: A DuckDB connection to the input tables in the model.
- `variables`: A dictionary of [TulipaVariable](@ref TulipaVariable)s containing the variables of the model.
- `expressions`: A dictionary of [TulipaExpression](@ref TulipaExpression)s containing the expressions of the model attached to tables.
- `constraints`: A dictionary of [TulipaConstraint](@ref TulipaConstraint)s containing the constraints of the model.
- `profiles`: Holds the profiles per `rep_period` or `over_clustered_year` in dictionary format. See [ProfileLookup](@ref).
- `model_parameters`: A [ModelParameters](@ref ModelParameters) structure to store all the parameters that are exclusive of the model.
- `model`: A JuMP.Model object representing the optimization model.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem (Float64).
- `termination_status`: The termination status of the optimization model.

### Constructor

The `EnergyProblem` can also be constructed using the minimal constructor below.

- `EnergyProblem(connection)`: Constructs a new `EnergyProblem` object with the given `connection` that has been created and the data loaded into it using [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl).

See the [basic example tutorial](@ref basic-example) to see how these can be used.

## GraphAssetData

This structure holds all the information of a given asset.
These are stored inside the Graph.
Given a graph `graph`, an asset `a` can be accessed through `graph[a]`.

## GraphFlowData

This structure holds all the information of a given flow.
These are stored inside the Graph.
Given a graph `graph`, a flow from asset `u` to asset `v` can be accessed through `graph[u, v]`.

## [Timeframe](@id timeframe)

The timeframe is the total period we want to analyze with the model. Usually this is a year, but it can be any length of time. A timeframe has two fields:

- `num_periods`: The timeframe is defined by a certain number of periods. For instance, a year can be defined by 365 periods, each describing a day.
- `map_periods_to_rp`: Indicates the periods of the timeframe that map into a [representative period](@ref representative-periods) and the weight of the representative period to construct that period.

## [Representative Periods](@id representative-periods)

The [timeframe](@ref timeframe) (e.g., a full year) is described by a selection of representative periods, for instance, days or weeks, that nicely summarize other similar periods. For example, we could model the year into 3 days, by clustering all days of the year into 3 representative days. Each one of these days is called a representative period. _TulipaEnergyModel.jl_ has the flexibility to consider representative periods of different lengths for the same timeframe (e.g., a year can be represented by a set of 4 days and 2 weeks). To obtain the representative periods, we recommend using [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl).

A representative period has three fields:

- `weight`: Indicates how many representative periods are contained in the [timeframe](@ref timeframe); this is inferred automatically from `map_periods_to_rp` in the [timeframe](@ref timeframe).
- `timesteps`: The number of timesteps blocks in the representative period.
- `resolution`: The duration in time of each timestep.

The number of timesteps and resolution work together to define the coarseness of the period.
Nothing is defined outside of these timesteps; for instance, if the representative period represents a day and you want to specify a variable or constraint with a coarseness of 30 minutes. You need to define the number of timesteps to 48 and the resolution to `0.5`.

## [Time Blocks](@id time-blocks)

A time block is a range for which a variable or constraint is defined.
It is a range of numbers, i.e., all integer numbers inside an interval.
Time blocks are used for the periods in the [timeframe](@ref timeframe) and the timesteps in the [representative period](@ref representative-periods). Time blocks are disjunct (not overlapping), but do not have to be sequential.
