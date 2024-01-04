export default_parameters, read_parameters_from_file

"""
    default_parameters(Val(optimizer_name_symbol))
    default_parameters(optimizer)
    default_parameters(optimizer_name_symbol)
    default_parameters(optimizer_name_string)

Returns the default parameters for a given JuMP optimizer.
Falls back to `Dict()` for undefined solvers.

## Arguments

There are four ways to use this function:

  - `Val(optimizer_name_symbol)`: This uses type dispatch with the special `Val` type.
    Just give the solver name as a Symbol (e.g., `Val(:HiGHS)`).
  - `optimizer`: The JuMP optimizer type (e.g., `HiGHS.Optimizer`).
  - `optimizer_name_symbol` or `optimizer_name_string`: Just give the name in Symbol
    or String format and we will convert to `Val`.

Using `Val` is necessary for the dispatch.
All other cases will convert the argument and call the `Val` version, which might lead to some type instability.

## Examples

```jldoctest
using HiGHS
default_parameters(HiGHS.Optimizer)

# output

Dict{String, Any} with 1 entry:
  "output_flag" => false
```

Another case

```jldoctest
default_parameters(Val(:Cbc))

# output

Dict{String, Any} with 1 entry:
  "logLevel" => 0
```

```jldoctest
default_parameters(:Cbc) == default_parameters("Cbc") == default_parameters(Val(:Cbc))

# output

true
```
"""
default_parameters(::Any) = Dict{String,Any}()
default_parameters(::Val{:HiGHS}) = Dict{String,Any}("output_flag" => false)
default_parameters(::Val{:Cbc}) = Dict{String,Any}("logLevel" => 0)
default_parameters(::Val{:GLPK}) = Dict{String,Any}("msg_lev" => 0)

function default_parameters(::Type{T}) where {T<:MathOptInterface.AbstractOptimizer}
    solver_name = split(string(T), ".")[1]
    return default_parameters(Val(Symbol(solver_name)))
end

default_parameters(optimizer::Union{String,Symbol}) = default_parameters(Val(Symbol(optimizer)))

"""
    read_parameters_from_file(filepath)

Parse the parameters from a file into a dictionary.
The keys and values are NOT checked to be valid parameters for any specific solvers.

The file should contain a list of lines of the following type:

```toml
key = value
```

The file is parsed as [TOML](https://toml.io), which is very intuitive. See the example below.

## Example

```jldoctest
# Creating file
filepath, io = mktemp()
println(io,
  \"\"\"
    true_or_false = true
    integer_number = 5
    real_number1 = 3.14
    big_number = 6.66E06
    small_number = 1e-8
    string = "something"
  \"\"\"
)
close(io)
# Reading
read_parameters_from_file(filepath)

# output

Dict{String, Any} with 6 entries:
  "string"         => "something"
  "integer_number" => 5
  "small_number"   => 1.0e-8
  "true_or_false"  => true
  "real_number1"   => 3.14
  "big_number"     => 6.66e6
```
"""
function read_parameters_from_file(filepath)
    if !isfile(filepath)
        throw(ArgumentError("'$filepath' is not a file."))
    end

    return TOML.parsefile(filepath)
end
