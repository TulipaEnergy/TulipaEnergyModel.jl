mutable struct TOItem
    ncalls::Int
    time::Float64
end

function parse_timer_output_log(filename)

    # Figure out columns
    for line in readlines(filename)
        if contains("Section")(line)
        end
    end

    current_parent = ""
    current_level = 0
    regex_str = r"(\s*)([^\s].*[^\s])\s*([0-9]*)\s*([0-9.]+)[mμ]s\s*.*iB"
    for line in readlines(filename)
        m = match(regex_str, line)
        @warn line
        if isnothing(m)
            continue
        end

        @info m.captures
        return
    end
end

@info parse_timer_output_log("new-to.log")
