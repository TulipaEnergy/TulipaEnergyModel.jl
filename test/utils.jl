# file with auxiliary functions for the testing
include("data-simplest.jl")

function _read_csv_folder(connection, input_dir)
    schemas = TulipaEnergyModel.schema_per_table_name
    return TulipaIO.read_csv_folder(connection, input_dir; schemas)
end

function _tiny_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Tiny"))
    return connection
end

function _storage_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Storage"))
    return connection
end

function _is_constraint_equal(left, right)
    if !_is_constraint_equal_kernel(left, right)
        println("LEFT")
        _show_constraint(left)
        println("RIGHT")
        _show_constraint(right)
        false
    else
        true
    end
end

function _show_constraint(con)
    for (var, coef) in sort(con.func.terms; by = name)
        println(_signed_string(coef), " ", var)
    end
    println(_signed_string(con.func.constant))
    println(_sense_string(con.set))
    println(_signed_string(con.set))
    return println("")
end

_signed_string(x) = string(x >= 0 ? "+" : "-", " ", abs(x))
_signed_string(s::MathOptInterface.LessThan) = _signed_string(s.upper)
_signed_string(s::MathOptInterface.EqualTo) = _signed_string(s.value)
_signed_string(s::MathOptInterface.GreaterThan) = _signed_string(s.lower)

_sense_string(::MathOptInterface.LessThan) = "<="
_sense_string(::MathOptInterface.EqualTo) = "=="
_sense_string(::MathOptInterface.GreaterThan) = ">="

function _is_constraint_equal_kernel(left, right)
    left_terms, right_terms = left.func.terms, right.func.terms
    missing_in_right = setdiff(keys(left_terms), keys(right_terms))
    if !isempty(missing_in_right)
        @error string("missing in right constraint: ", missing_in_right)
        return false
    end
    missing_in_left = setdiff(keys(right_terms), keys(left_terms))
    if !isempty(missing_in_left)
        @error string("missing in left constraint: ", missing_in_left)
        return false
    end
    result = true
    for k in keys(left_terms)
        if !isapprox(left_terms[k], right_terms[k])
            @error string(left_terms[k], " != ", right_terms[k])
            result = false
        end
    end
    if left.set != right.set
        @error string(left.set, " != ", right.set)
        result = false
    end
    return result
end
