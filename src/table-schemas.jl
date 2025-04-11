# read schema from file

const table_schemas =
    JSON.parsefile(joinpath(@__DIR__, "table-schemas.json"); dicttype = OrderedDict);

const sql_input_schema_per_table_name = OrderedDict(
    schema_key => OrderedDict(key => value["type"] for (key, value) in schema_content) for
    (schema_key, schema_content) in table_schemas["input"]
)
const sql_cluster_schema_per_table_name = OrderedDict(
    schema_key => OrderedDict(key => value["type"] for (key, value) in schema_content) for
    (schema_key, schema_content) in table_schemas["cluster"]
)
