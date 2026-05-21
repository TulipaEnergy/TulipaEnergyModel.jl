# read schema from file
# include_dependency so precompile is invalidated when the JSON changes
include_dependency("input-schemas.json")

const schema =
    JSON.parsefile(joinpath(@__DIR__, "input-schemas.json"); dicttype = OrderedDict{String,Any});

const schema_per_table_name = OrderedDict(
    schema_key => OrderedDict(key => value["type"] for (key, value) in schema_content) for
    (schema_key, schema_content) in schema
)
