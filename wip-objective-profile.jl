using DuckDB
using DataFrames
using TulipaBuilder
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaClustering: TulipaClustering as TC

tulipa = TulipaData()
add_asset!(tulipa, "Producer", :producer)
add_asset!(tulipa, "Consumer", :consumer)
add_flow!(tulipa, "Producer", "Consumer"; commodity_price = 3.14)
attach_profile!(tulipa, "Producer", "Consumer", :commodity_price, 2030, [0.0; 1.0; 2.0])
# attach_profile!(tulipa, "Producer", "Consumer", :commodity_price, 2040, [0.0; 2.0; 4.0])
set_partition!(tulipa, "Producer", "Consumer", 2030, 1, "explicit", "1;2")
# set_partition!(tulipa, "Producer", "Consumer", 2040, 1, "explicit", "1;2")

connection = create_connection(tulipa, TEM.schema)
_q(s) = DataFrame(DuckDB.query(connection, s))
TC.dummy_cluster!(connection)
TEM.populate_with_defaults!(connection)
energy_problem = TEM.EnergyProblem(connection)
TEM.create_model!(energy_problem)

print(energy_problem.model)
