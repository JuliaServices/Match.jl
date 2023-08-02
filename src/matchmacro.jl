#
# Implementation of `@match pattern = value`
#
function handle_match_eq(location::LineNumberNode, mod::Module, expr)
    is_expr(expr, :(=), 2) ||
        error(string("Unrecognized @match syntax: ", expr))
    pattern = expr.args[1]
    value = expr.args[2]
    binder = BinderContext(mod)
    input_variable::Symbol = binder.input_variable
    (bound_pattern, assigned) = bind_pattern!(
        location, pattern, input_variable, binder, ImmutableDict{Symbol, Symbol}())
    simplified_pattern = simplify(bound_pattern, Set{Symbol}(values(assigned)), binder)
    matched = lower_pattern_to_boolean(simplified_pattern, binder)
    q = Expr(:block,
        location,

        # evaluate the assertions
        binder.assertions...,

        # compute the input into a variable so we do not repeat its side-effects
        :($input_variable = $value),

        # check that it matched the pattern; if not throw an exception
        :($matched || $throw($MatchFailure($input_variable))),

        # assign to pattern variables in the enclosing scope
        assignments(assigned)...,

        # finally, yield the input that was matched
        input_variable
    )
    esc(q)
end

#
# Implementation of `@ismatch value pattern`
#
function handle_ismatch(location::LineNumberNode, mod::Module, value, pattern)
    binder = BinderContext(mod)
    input_variable::Symbol = binder.input_variable
    bound_pattern, assigned = bind_pattern!(
        location, pattern, input_variable, binder, ImmutableDict{Symbol, Symbol}())
    simplified_pattern = simplify(bound_pattern, Set{Symbol}(values(assigned)), binder)
    matched = lower_pattern_to_boolean(simplified_pattern, binder)
    bindings = Expr(:block, assignments(assigned)..., true)
    result = Expr(:block,
        location,

        # evaluate the assertions
        binder.assertions...,

        # compute the input into a variable so we do not repeat its side-effects
        :($input_variable = $value),

        # check that it matched the pattern; if so assign pattern variables
        :($matched && $bindings)
    )
    esc(result)
end

#
# """
# Usage:
#
# ```
#     @match pattern = value
# ```
#
# If `value` matches `pattern`, bind variables and return `value`.
# Otherwise, throw `MatchFailure`.
# """
#
macro match(expr)
    handle_match_eq(__source__, __module__, expr)
end

"""
Usage:
```
    @__match__ value begin
        pattern1 => result1
        pattern2 => result2
        ...
    end
```

Return `result` for the first matching `pattern`.
If there are no matches, throw `MatchFailure`.
This uses a brute-force code gen strategy, essentially a series of if-else statements.
It is used for testing purposes, as a reference for correct semantics.
Because it is so simple, we have confidence about its correctness.
"""
macro __match__(value, cases)
    handle_match_cases_simple(__source__, __module__, value, cases)
end

#
# """
# Usage:
# ```
#     @match value begin
#         pattern1 => result1
#         pattern2 => result2
#         ...
#     end
# ```

# Return `result` for the first matching `pattern`.
# If there are no matches, throw `MatchFailure`.
# """
#
macro match(value, cases)
    handle_match_cases(__source__, __module__, value, cases)
end

#
# """
# Usage:
# ```
#     @ismatch value pattern
# ```
#
# Return `true` if `value` matches `pattern`, `false` otherwise.  When returning `true`,
# binds the pattern variables in the enclosing scope.
# """
#
macro ismatch(value, pattern)
    handle_ismatch(__source__, __module__, value, pattern)
end
