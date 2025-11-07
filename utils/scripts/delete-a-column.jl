# Use to delete a specific column in a specific table
using DuckDB

root_dir = joinpath(@__DIR__, "..", "..")
test_inputs = joinpath(root_dir, "test", "inputs")
dirs = readdir(test_inputs; join = true)
push!(dirs, joinpath(root_dir, "benchmark", "EU"))

for dir in dirs
    if !isdir(dir)
        continue
    end
    println("Processing directory: $dir")

    # Explicit name of the table
    filename = joinpath(dir, "profiles-rep-periods.csv")

    connection = DBInterface.connect(DuckDB.DB)
    _q(s) = DuckDB.query(connection, s)

    _q("CREATE TABLE t AS FROM read_csv('$filename')")

    # Delete a column by name
    _q("ALTER TABLE t DROP COLUMN scenario")

    _q("COPY t TO '$filename' (HEADER, DELIMITER ',')")
end
