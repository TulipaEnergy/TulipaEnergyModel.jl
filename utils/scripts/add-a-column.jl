# Use to update a specific column in a specific table
using DuckDB

root_dir = joinpath(@__DIR__, "..", "..")
test_inputs = joinpath(root_dir, "test", "inputs")
#tutorial_inputs = joinpath(root_dir, "docs/src/10-tutorials/my-awesome-energy-system")

test_dirs = readdir(test_inputs; join = true)
#tutorial_dirs = readdir(tutorial_inputs; join = true)
dirs = vcat(test_dirs, tutorial_dirs)
push!(dirs, joinpath(root_dir, "benchmark", "EU"))

for dir in dirs
    if !isdir(dir)
        continue
    end
    println("Processing directory: $dir")

    # Explicit name of the table
    filename = joinpath(dir, "asset.csv")

    connection = DBInterface.connect(DuckDB.DB)
    _q(s) = DuckDB.query(connection, s)

    _q("CREATE TABLE t AS FROM read_csv('$filename')")

    # Add a new column with a default value
    _q("ALTER TABLE t ADD COLUMN unit_commitment STRING DEFAULT 'none'")

    _q("COPY t TO '$filename' (HEADER, DELIMITER ',')")
end
