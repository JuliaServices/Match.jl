struct MatchCaseResult
    location::LineNumberNode
    matched_expression::Any
    result_expression::Any
end

function handle_match_cases_simple(location::LineNumberNode, mod::Module, value, match)
    if is_case(match)
        # previous version of @match supports `@match(expr, pattern => value)`
        match = Expr(:block, location, match)
    elseif !is_expr(match, :block)
        error("$(location.file):$(location.line): Unrecognized @match block syntax: `$match`.")
    end

    binder = BinderContext(mod)
    input_variable::Symbol = binder.input_variable
    cases = MatchCaseResult[]
    predeclared_temps = Any[]

    for case in match.args
        if case isa LineNumberNode
            location = case
        else
            bound_case = bind_case(length(cases) + 1, location, case, predeclared_temps, binder)
            matched = lower_pattern_to_boolean(bound_case.pattern, binder)
            push!(cases, MatchCaseResult(location, matched, code(bound_case.result_expression)))
        end
    end

    # Fold the cases into a series of if-elseif-else statements
    body = foldr(enumerate(cases); init = :($throw($MatchFailure($input_variable)))) do (i, case), tail
        Expr(i == 1 ? :if : :elseif, case.matched_expression, case.result_expression, tail)
    end

    declare_temps = Expr(:block, predeclared_temps...)
    body = Expr(:block,
        location,
        binder.assertions...,
        :($input_variable = $value),
        body)

    # We use a `let` to ensure consistent closed scoping
    body = Expr(:let, declare_temps, body)
    esc(body)
end
