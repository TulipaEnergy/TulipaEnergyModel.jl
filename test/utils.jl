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

function _multi_year_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Multi-year Investments"))
    return connection
end

function _is_constraint_equal(left, right)
    if !_is_constraint_equal_kernel(left, right)
        println("LEFT")
        _show_constraint(left)
        println("RIGHT")
        _show_constraint(right)
        return false
    else
        return true
    end
end

function _is_constraint_equal(expected_vec::Vector, observed_vec::Vector)
    if length(expected_vec) != length(observed_vec)
        @error "Vector lengths differ: expected $(length(expected_vec)), observed $(length(observed_vec))"
        return false
    end

    for (i, (expected, observed)) in enumerate(zip(expected_vec, observed_vec))
        if !_is_constraint_equal(expected, observed)
            @error "Constraint $i differs"
            return false
        end
    end
    return true
end

function _show_constraint(con)
    for (var, coef) in sort(con.func.terms; by = JuMP.name)
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

function _get_cons_object(model::JuMP.GenericModel, name::Symbol)
    return [JuMP.constraint_object(con) for con in model[name]]
end

function _test_variable_properties(
    variable::JuMP.GenericVariableRef,
    lower_bound::Union{Nothing,Float64},
    upper_bound::Union{Nothing,Float64};
    is_integer::Bool = false,
    is_binary::Bool = false,
)
    if isnothing(lower_bound)
        @test !JuMP.has_lower_bound(variable)
    else
        @test JuMP.lower_bound(variable) == lower_bound
    end

    if isnothing(upper_bound)
        @test !JuMP.has_upper_bound(variable)
    else
        @test JuMP.upper_bound(variable) == upper_bound
    end

    @test JuMP.is_integer(variable) == is_integer
    @test JuMP.is_binary(variable) == is_binary

    return nothing
end

function _create_table_for_tests(
    connection::DuckDB.DB,
    table_name::String,
    table_rows::Vector{<:Tuple},
    columns::Vector{Symbol},
)
    df = DataFrame(table_rows, columns)
    DuckDB.register_data_frame(connection, df, table_name)
    return nothing
end
