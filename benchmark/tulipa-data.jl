using TulipaBuilder: TulipaBuilder as TB
using TulipaClustering: TulipaClustering as TC

"""
    give_me_better_name(; kwargs...)

Create a fake problem with `num_countries` countries.
Each country has:

- A thermal generator
    - random capacity from 100 KW to 1000 KW, 1 initial unit.
- A solar farm
    - random capacity from 100 KW to 1000 KW, investable with integer units with cost of \$ 50 / unit.
    - profile simulating solar availability
- A consumer
    - random peak demand from 10 KW to 100 KW, with
    - random demand profile between 0.8 and 1.0
- A storage
- Flows from the thermal generator, solar farm, and storage to the consumer, and from the consumer to the storage.
- Flows between the consumer of a country and two other countries
    - The countries are numbered, and each country connects to the previous and next country.

## Keyword arguments:

- `num_countries`: Control the number of countries. Default: 3
- `num_days`: Number of days in the profile. Default: 365
- `num_rep_periods`: Number of representative periods. Default: 3
- `period_duration`: Number of time steps in the day. Default: 24
"""
function give_me_better_name(;
    num_countries = 3,
    num_days = 365,
    num_rep_periods = 3,
    period_duration = 24,
)
    @assert num_countries > 0
    @assert num_days > 0
    @assert num_rep_periods > 0
    @assert period_duration > 0
    tulipa = TB.TulipaData()

    for country_id in 1:num_countries
        country = "Country$country_id"
        thermal = "$(country)_thermal"
        solar = "$(country)_solar"
        demand = "$(country)_demand"
        storage = "$(country)_storage"
        TB.add_asset!(
            tulipa,
            thermal,
            :producer;
            capacity = rand(100:100:1000),
            initial_units = 1.0,
        )
        TB.add_asset!(
            tulipa,
            solar,
            :producer;
            capacity = rand(100:100:1000),
            investable = true,
            investment_integer = true,
            investment_cost = 50.0,
        )
        TB.add_asset!(tulipa, demand, :consumer; peak_demand = rand(10:10:100))
        TB.add_asset!(tulipa, storage, :storage)
        TB.add_flow!(tulipa, thermal, demand; operational_cost = 0.2)
        TB.add_flow!(tulipa, solar, demand)
        TB.add_flow!(tulipa, storage, demand)
        TB.add_flow!(tulipa, demand, storage)
        solar_decay = [
            begin
                s = 0.18 + 0.12 * (cos(2d * pi / num_days) + 1) / 2 # because it looks nice
                if rand() < 0.25
                    s *= 0.05 # Darker days
                end
                s *= (1 - rand() * 0.4) # Day randomness
                s
            end for d in 1:num_days
        ]
        solar_profile = [
            begin
                exp(-solar_decay[d] * (t - 12)^2)^(1 / 4) * (1 + randn() * 0.1)
            end for d in 1:num_days for t in 1:period_duration
        ]
        TB.attach_profile!(tulipa, solar, :availability, 2030, solar_profile)
        demand_profile = 0.8 .+ 0.2 * rand(period_duration * num_days)
        TB.attach_profile!(tulipa, demand, :demand, 2030, demand_profile)

        if country_id > 1
            other = "Country$(country_id-1)_demand"
            TB.add_flow!(tulipa, demand, other; operational_cost = 0.01)
            TB.add_flow!(tulipa, other, demand; operational_cost = 0.01)
        end
        if country_id == num_countries && num_countries > 2
            other = "Country1_demand"
            TB.add_flow!(tulipa, demand, other; operational_cost = 0.01)
            TB.add_flow!(tulipa, other, demand; operational_cost = 0.01)
        end
    end

    connection = TB.create_connection(tulipa)

    TC.cluster!(connection, period_duration, num_rep_periods)

    return connection, tulipa
end
