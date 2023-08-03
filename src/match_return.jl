"""
    @match_fail

This statement permits early-exit from the value of a @match case.
The programmer may write the value as a `begin ... end` and then,
within the value, the programmer may write

    @match_fail

to cause the case to terminate as if its pattern had failed.
This permits cases to perform some computation before deciding if the
rule "*really*" matched.
"""
macro match_fail()
    # These are rewritten during expansion of the `@match` macro,
    # so the actual macro should not be used directly.
    error("$(__source__.file):$(__source__.line): @match_fail may only be used within the value of a @match case.")
end

"""
    @match_return value

This statement permits early-exit from the value of a @match case.
The programmer may write the value as a `begin ... end` and then,
within the value, the programmer may write

    @match_return value

to terminate the value expression **early** with success, with the
given value.
"""
macro match_return(x)
    # These are rewritten during expansion of the `@match` macro,
    # so the actual macro should not be used.
    error("$(__source__.file):$(__source__.line): @match_return may only be used within the value of a @match case.")
end

#
# We implement @match_fail and @match_return as follows:
#
# Given a case (part of a @match)
#
#    pattern => value
#
# in which the value part contains a use of one of these macros, we create
# two synthetic names: one for a `label`, and one for an intermediate `temp`.
# Then we rewrite `value` into `new_value` by replacing every occurrence of
#
#    @match_return value
#
# with
#
#    begin
#        $temp = $value
#        @goto $label
#    end
#
# and every occurrence of
#
#    @match_fail
#
# With
#
#    @match_return $MatchFailure
#
# And then we replace the whole `pattern => value` with
#
#    pattern where begin
#        $temp = $value'
#        @label $label
#        $tmp !== $MatchFailure
#        end => $temp
#
# Note that we are using the type `MatchFailure` as a sentinel value to indicate that the
# match failed.  Therefore, don't use the @match_fail and @match_return macros for cases
# in which `MatchFailure` is a possible result.
#
function adjust_case_for_return_macro(__module__, location, pattern, result, predeclared_temps)
    value = gensym("value")
    label = gensym("label")
    found_early_exit::Bool = false
    function adjust_top(p)
        is_expr(p, :macrocall) || return p
        if length(p.args) == 3 &&
            (p.args[1] == :var"@match_return"  || p.args[1] == Expr(:., Symbol(string(@__MODULE__)), QuoteNode(:var"@match_return")))
            # :(@match_return e) -> :($value = $e; @goto $label)
            found_early_exit = true
            return Expr(:block, p.args[2], :($value = $(p.args[3])), :(@goto $label))
        elseif length(p.args) == 2 &&
            (p.args[1] == :var"@match_fail"  || p.args[1] == Expr(:., Symbol(string(@__MODULE__)), QuoteNode(:var"@match_fail")))
            # :(@match_fail) -> :($value = $MatchFaulure; @goto $label)
            found_early_exit = true
            return Expr(:block, p.args[2], :($value = $MatchFailure), :(@goto $label))
        elseif length(p.args) == 4 &&
            (p.args[1] == :var"@match" || p.args[1] == Expr(:., Symbol(string(@__MODULE__)), QuoteNode(:var"@match")) ||
             p.args[1] == :var"@match" || p.args[1] == Expr(:., Symbol(string(@__MODULE__)), QuoteNode(:var"@match")))
            # Nested uses of @match should be treated as independent
            return macroexpand(__module__, p)
        else
            # It is possible for a macro to expand into @match_fail, so only expand one step.
            return adjust_top(macroexpand(__module__, p; recursive = false))
        end
    end

    rewritten_result = MacroTools.prewalk(adjust_top, result)
    if found_early_exit
        # Since we found an early exit, we need to predeclare the temp to ensure
        # it is in scope both for where it is written and in the constructed where clause.
        push!(predeclared_temps, value)
        where_expr = Expr(:block, location, :($value = $rewritten_result), :(@label $label), :($value !== $MatchFailure))
        new_pattern = :($pattern where $where_expr)
        new_result = value
        (new_pattern, new_result)
    else
        (pattern, rewritten_result)
    end
end
