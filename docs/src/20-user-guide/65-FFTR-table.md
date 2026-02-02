# [FFTR Constraints Table](@id fftr-table)

To correctly handle [fully-flexible time resolution (FFTR)](@ref flex-time-res), we must explicitly state how the constraints are constructed. For each constraint, three things need to be considered:

1. The type of constraint balance:
   - _power_: highest resolution
   - _energy_: lowest resolution (multiplied by durations)
1. How the resolution is determined (regardless of whether it is highest or lowest):
   - the _incoming_ flows
   - the _outgoing_ flows
   - or a combination of _both_
1. How the related parameters are aggregated:
   - _sum_
   - _mean_

Below is the table outlining the details for each type of constraint.

!!! tip "Before reading the table consider this:"
    To calculate the resolution of the constraints we use the `min` function to determine which is the highest resolution in the constraint, and the `max` function to determine the lowest resolution in the constraint.
    For example, the consumer balance is defined as `power` type, and it involves the inputs and outputs, then the constraint resolution must be the minimum resolution among them to ensure it is on the `highest resolution`. Then, if you have an input of `1h` resolution and an output of `2h` resolution; then the resolution of the constraint must be `1h` (i.e., `min(1h,2h)`).

| Name                                           | Variables involved             | Profile involved | Constraint type | Resolution of the constraints                                                            | Profile aggregation |
| ---------------------------------------------- | ------------------------------ | ---------------- | --------------- | ---------------------------------------------------------------------------------------- | ------------------- |
| Consumer Balance                               | inputs, outputs                | demand           | power           | min(incoming flows, outgoing flows)                                                      | mean                |
| Storage Balance                                | inputs, outputs, storage level | inflows          | energy          | max(asset, min(incoming flows, outgoing flows))                                          | sum                 |
| Hub Balance                                    | inputs, outputs                | -                | power           | min(incoming flows, outgoing flows)                                                      | -                   |
| Conversion Balance                             | inputs, outputs [^1]           | -                | energy          | max(incoming flows, outgoing flows)                                                      | -                   |
| Producers Capacity Constraints                 | outputs                        | availability     | power           | min(outgoing flows)                                                                      | mean                |
| Storage Capacity Constraints (outgoing)        | outputs                        | -                | power           | min(outgoing flows)                                                                      | -                   |
| Conversion Capacity Constraints (outgoing)     | outputs                        | -                | power           | min(outgoing flows)                                                                      | -                   |
| Conversion Capacity Constraints (incoming)     | inputs                         | -                | power           | min(incoming flows)                                                                      | -                   |
| Storage Capacity Constraints (incoming)        | inputs                         | -                | power           | min(incoming flows)                                                                      | -                   |
| Transport Capacity Constraints (upper bounds)  | flow                           | availability     | power           | if it connects two hubs or demands then max(hub a,hub b), otherwise its own              | mean                |
| Transport Capacity Constraints (lower bounds)  | flow                           | availability     | power           | if it connects two hubs or demands then max(hub a,hub b), otherwise its own              | mean                |
| Maximum Energy Limits (outgoing)               | outputs                        | max_energy       | energy          | Determine by timeframe partitions. The default value is for each period in the timeframe | sum                 |
| Minimum Energy Limits (outgoing)               | outputs                        | min_energy       | energy          | Determine by timeframe partitions. The default value is for each period in the timeframe | sum                 |
| Maximum Output Flow with Unit Commitment       | outputs, units_on              | availability     | power           | min(outgoing flows, units_on)                                                            | mean                |
| Minimum Output Flow with Unit Commitment       | outputs, units_on              | availability     | power           | min(outgoing flows, units_on)                                                            | mean                |
| Maximum Ramp Up Flow with Unit Commitment      | outputs, units_on              | availability     | power           | min(outgoing flows, units_on)                                                            | mean                |
| Maximum Ramp Down Flow with Unit Commitment    | outputs, units_on              | availability     | power           | min(outgoing flows, units_on)                                                            | mean                |
| Maximum Ramp Up Flow without Unit Commitment   | outputs                        | availability     | power           | min(outgoing flows)                                                                      | mean                |
| Maximum Ramp Down Flow without Unit Commitment | outputs                        | availability     | power           | min(outgoing flows)                                                                      | mean                |
| DC-OPF Constraint                              | flow, electricity_angle        | -                | power           | min(neighboring assets, flow)                                                            | -                   |
| Flows relationships                            | flow 1, flow 2                 | -                | energy          | max(flow1, flow2)                                                                        | -                   |

[^1]: Only inputs or outputs with [`conversion coefficient`](@ref coefficient-for-conversion-constraints) $\geq 0$ are considered to determine the resolution of the conversion balance constraint.
