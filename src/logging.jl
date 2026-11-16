const LOG_LEVELS = (:minimal, :detailed)
const LOG_LEVEL = Ref{Symbol}(:detailed)

"""
    set_log_level!(log_level)

Set the package logging level to `:minimal` or `:detailed`.

The minimal level reports high-level scenario progress. The detailed level also
reports internal model construction steps. Use `show_log = false` in individual
functions to silence their progress logging entirely.
"""
function set_log_level!(log_level::Symbol)
    if log_level ∉ LOG_LEVELS
        throw(ArgumentError("Unsupported log level `$log_level`. Use one of $(LOG_LEVELS)."))
    end

    LOG_LEVEL[] = log_level
    return
end

function _is_detailed_logging()
    return LOG_LEVEL[] === :detailed
end

function _log_detailed(message)
    if _is_detailed_logging()
        @info message
    end
    return
end
