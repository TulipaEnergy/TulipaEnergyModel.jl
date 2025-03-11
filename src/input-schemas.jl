# read schema from file

schema = JSON.parsefile(joinpath(@__DIR__, "input-schemas.json"); dicttype = OrderedDict);

const schema_per_table_name = OrderedDict(
    schema_key => OrderedDict(key => value["type"] for (key, value) in schema_content) for
    (schema_key, schema_content) in schema
)
