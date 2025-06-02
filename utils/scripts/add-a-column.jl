# Use to update a specific column in a specific table
using DuckDB

root_dir = joinpath(@__DIR__, "..", "..")
test_inputs = joinpath(root_dir, "test", "inputs")
dirs = readdir(test_inputs; join = true)
push!(dirs, joinpath(root_dir, "benchmark", "EU"))

for dir in dirs
    if !isdir(dir)
        continue
    end

    # Explicit name of the table
    filename = joinpath(dir, "flow-commission.csv")

    connection = DBInterface.connect(DuckDB.DB)
    _q(s) = DuckDB.query(connection, s)

    _q("CREATE TABLE t AS FROM read_csv('$filename')")

    # Add a new column with a default value
    _q("ALTER TABLE t ADD COLUMN conversion_coefficient DOUBLE DEFAULT 1")

    _q("COPY t TO '$filename' (HEADER, DELIMITER ',')")
end
