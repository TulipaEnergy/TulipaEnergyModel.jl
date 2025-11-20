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
    filename = joinpath(dir, "asset-commission.csv")

    connection = DBInterface.connect(DuckDB.DB)
    _q(s) = DuckDB.query(connection, s)

    _q("CREATE TABLE t AS FROM read_csv('$filename')")

    # Change the column name
    try
        _q("ALTER TABLE t RENAME COLUMN efficiency TO conversion_efficiency")
    catch err
        @info "Skipping rename; column not found" filename exception = err
    end

    _q("COPY t TO '$filename' (HEADER, DELIMITER ',')")
end
