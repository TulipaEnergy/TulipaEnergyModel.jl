const SHOW_LOG_LEVELS = (:none, :minimal, :detailed)

"""
    _validate_show_log(show_log)

Validate a `show_log` value.

Use `:none` to silence progress logging, `:minimal` for high-level scenario
progress, or `:detailed` to include internal model construction steps.
"""
function _validate_show_log(show_log::Symbol)
    if show_log ∉ SHOW_LOG_LEVELS
        throw(
            ArgumentError("Unsupported show_log value `$show_log`. Use one of $(SHOW_LOG_LEVELS)."),
        )
    end
    return show_log
end

function _is_detailed_logging(show_log::Symbol)
    return show_log === :detailed
end

function _log_minimal(show_log::Symbol, message)
    if show_log !== :none
        @info message
    end
    return
end

function _log_detailed(show_log::Symbol, message)
    if _is_detailed_logging(show_log)
        @info message
    end
    return
end
