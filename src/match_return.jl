macro match_fail()
    # These are rewritten during expansion of the `@match` macro.
    Expr(:call, :__match_fail__, QuoteNode(__source__))
end

macro match_return(x)
    # These are rewritten during expansion of the `@match` macro.
    Expr(:call, :__match_return__, QuoteNode(__source__), esc(x))
end

function __match_fail__(location)
    error("$(location.file):$(location.line): @match_fail may only be used within the value of a @match case.")
end

function __match_return__(location, _)
    error("$(location.file):$(location.line): @match_return may only be used within the value of a @match case.")
end

# is f a reference to the __match_fail__ function?
function is_match_fail(f)
    f == Match.__match_fail__ || f == GlobalRef(Match, :__match_fail__)
end

# is f a reference to the __match_return__ function?
function is_match_return(f)
    f == Match.__match_return__ || f == GlobalRef(Match, :__match_return__)
end

# is f an early exit function?
function is_early_exit(f)
    is_match_fail(f) || is_match_return(f)
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
    found_early_exit::Bool = false

    # Check for the presence of early exit macros
    function adjust_top(p)
        if !found_early_exit && is_expr(p, :call)
            f = p.args[1]
            if is_early_exit(f)
                found_early_exit = true
            end
        end
        return p
    end
    MacroTools.postwalk(adjust_top, result)

    if found_early_exit
        # Since we found an early exit, we need to predeclare the temp to ensure
        # it is in scope both for where it is written and in the constructed where clause.
        value_symbol = gensym("value")
        push!(predeclared_temps, value_symbol)
        
        # Defer generation of the label and branch, so we get a unique label in case it needs to be generated more than once.
        where_expr = where_expression_requiring_adjustment_for_return_macro(value_symbol, location, result)
        new_pattern = :($pattern where $where_expr)
        new_result = value_symbol
        (new_pattern, new_result)
    else
        (pattern, result)
    end
end

const marker_for_where_expression_requiring_adjustment_for_return_macro =
    :where_expression_requiring_adjustment_for_return_macro

# We defer generating the code for the where clause with the label, because
# the state machine may require it to be generated more than once, and each
# generated version must use a fresh new label to avoid a duplicate label
# in the generated code.
function where_expression_requiring_adjustment_for_return_macro(
    value_symbol::Symbol,
    location,
    expression_containing_macro)
    Expr(marker_for_where_expression_requiring_adjustment_for_return_macro,
         value_symbol, location, expression_containing_macro)
end

# See doc for where_expression_requiring_adjustment_for_return_macro, above
code_for_expression(x) = x
function code_for_expression(x::Expr)
    x.head == marker_for_where_expression_requiring_adjustment_for_return_macro || return x
    value_symbol, location, expression_containing_macro = x.args
    label = gensym("early_label")

    function adjust_top(result)
        is_expr(result, :call) || return result
        f = result.args[1]
        new_result = if is_match_return(f)
            _, source, value = result.args
            # :(@match_return e) -> :($value = $e; @goto $label)
            Expr(:block, source, :($value_symbol = $(value)), :(@goto $label))
        elseif is_match_fail(f)
            _, source = result.args
            # :(@match_fail) -> :($value = $MatchFaulure; @goto $label)
            Expr(:block, source, :($value_symbol = $MatchFailure), :(@goto $label))
        else
            result
        end
        return new_result
    end

    rewritten_result = MacroTools.prewalk(adjust_top, expression_containing_macro)
    Expr(:block, location, :($value_symbol = $rewritten_result),
         :(@label $label), :($value_symbol !== $MatchFailure))
end
