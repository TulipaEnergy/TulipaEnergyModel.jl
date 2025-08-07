@testsnippet CommonSetup begin
    using CSV: CSV
    using DataFrames: DataFrames, DataFrame
    using DuckDB: DuckDB, DBInterface
    using GLPK: GLPK
    using HiGHS: HiGHS
    using JuMP: JuMP
    using MathOptInterface: MathOptInterface
    using Test: Test, @test, @testset, @test_throws, @test_logs
    using TOML: TOML
    using TulipaEnergyModel: TulipaEnergyModel
    using TulipaIO: TulipaIO

    INPUT_FOLDER = joinpath(@__DIR__, "inputs")
    export INPUT_FOLDER

    function _create_connection_from_dict(data::Dict{String,DataFrame})
        connection = DBInterface.connect(DuckDB.DB)

        for (table_name::String, table::DataFrame) in data
            # Check that these `table_name` exist in the schema
            if !haskey(TulipaEnergyModel.schema_per_table_name, table_name)
                error("Table '$table_name' does not exist")
            end
            DuckDB.register_data_frame(connection, table, table_name)
        end

        return connection
    end

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

    """
        _create_table_for_tests(connection, table_name, table_rows, columns)

    Create a non-empty table for tests.
    """
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

    """
        _create_empty_table_for_tests(connection, table_name, columns_with_types)

    Create an empty table with a specific schema for tests. The `columns_with_types` can be a dictionary or a vector of pairs.
    """
    function _create_empty_table_for_tests(
        connection::DuckDB.DB,
        table_name::String,
        columns_with_types::Union{Dict{Symbol,DataType},Vector{Pair{Symbol,DataType}}},
    )
        df = DataFrame(Dict(name => col_type[] for (name, col_type) in columns_with_types))
        DuckDB.register_data_frame(connection, df, table_name)
        return nothing
    end
end

@testmodule TestData begin
    const simplest_data = Dict(
        # Basic asset data
        "asset" => DataFrame(
            :asset => ["some_producer", "some_consumer"],
            :type => ["producer", "consumer"],
        ),
        "asset_both" => DataFrame(
            :asset => ["some_producer", "some_consumer"],
            :commission_year => [2030, 2030],
            :milestone_year => [2030, 2030],
        ),
        "asset_commission" => DataFrame(
            :asset => ["some_producer", "some_consumer"],
            :commission_year => [2030, 2030],
        ),
        "asset_milestone" => DataFrame(
            :asset => ["some_producer", "some_consumer"],
            :milestone_year => [2030, 2030],
        ),

        # Basic flow data
        "flow" => DataFrame(:from_asset => ["some_producer"], :to_asset => ["some_consumer"]),
        "flow_both" => DataFrame(
            :from_asset => String[],
            :to_asset => String[],
            :commission_year => Int[],
            :milestone_year => Int[],
        ),
        "flow_commission" => DataFrame(
            :from_asset => ["some_producer"],
            :to_asset => ["some_consumer"],
            :commission_year => [2030],
        ),
        "flow_milestone" => DataFrame(
            :from_asset => ["some_producer"],
            :to_asset => ["some_consumer"],
            :milestone_year => [2030],
        ),

        # Basic time information
        "year_data" => DataFrame(:year => [2030]),
        "rep_periods_data" => DataFrame(:year => [2030, 2030], :rep_period => [1, 2]),
        "timeframe_data" => DataFrame(:year => 2030, :period => 1:365),
        "rep_periods_mapping" =>
            DataFrame(:year => 2030, :period => 1:365, :rep_period => mod1.(1:365, 2)),
    )
end
