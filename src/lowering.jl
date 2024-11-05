# compute whether or not a constant pattern matches a value at runtime
pattern_matches_value(pattern, input) = isequal(pattern, input)
pattern_matches_value(r::AbstractRange, i) = i in r || isequal(i, r)
# For compat with Match.jl we permit a Regex to match an identical Regex by isequal
pattern_matches_value(r::Regex, s::AbstractString) = occursin(r, s)

function assignments(assigned::ImmutableDict{Symbol, Symbol})
    # produce a list of assignments to be splatted into the caller
    return (:($patvar = $resultsym) for (patvar, resultsym) in assigned if resultsym !== unusable_variable)
end

function code(e::BoundExpression)
    value = Expr(:block, e.location, source(e))
    assignments = Expr(:block, (:($k = $v) for (k, v) in e.assignments)...)
    return Expr(:let, assignments, value)
end

# return the code needed for a pattern.
code(bound_pattern::BoundTruePattern, binder::BinderContext) = true
function code(bound_pattern::BoundIsMatchTestPattern, binder::BinderContext)
    func = bound_pattern.force_equality ? Base.isequal : (@__MODULE__).pattern_matches_value
    :($func($(code(bound_pattern.bound_expression)), $(bound_pattern.input)))
end
function code(bound_pattern::BoundRelationalTestPattern, binder::BinderContext)
    @assert bound_pattern.relation == :>=
    :($(bound_pattern.relation)($(bound_pattern.input), $(bound_pattern.value)))
end
function code(bound_pattern::BoundWhereTestPattern, binder::BinderContext)
    bound_pattern.inverted ? :(!$(bound_pattern.input)) : bound_pattern.input
end
function code(bound_pattern::BoundTypeTestPattern, binder::BinderContext)
    # We assert that the type is invariant.  Because this mutates binder.assertions,
    # you must take the value of binder.assertions after all calls to the generated code.
    src = source(bound_pattern)
    if src != bound_pattern.type && !(src in binder.asserted_types)
        test = :($(bound_pattern.type) == $src)
        thrown = :($throw($AssertionError($string($(string(bound_pattern.location.file)),
            ":", $(bound_pattern.location.line),
            ": The type syntax `::", $(string(src)), "` bound to type ",
            $string($(bound_pattern.type)), " at macro expansion time but ",
             $src, " later."))))
        push!(binder.assertions, Expr(:block, bound_pattern.location, :($test || $thrown)))
        push!(binder.asserted_types, )
    end
    :($(bound_pattern.input) isa $(bound_pattern.type))
end
function code(bound_pattern::BoundOrPattern, binder::BinderContext)
    :($(mapreduce(bp -> lower_pattern_to_boolean(bp, binder),
            (a, b) -> :($a || $b),
            bound_pattern.subpatterns)))
end
function code(bound_pattern::BoundAndPattern, binder::BinderContext)
    :($(mapreduce(bp -> lower_pattern_to_boolean(bp, binder),
            (a, b) -> :($a && $b),
            bound_pattern.subpatterns)))
end
function code(bound_pattern::BoundFetchPattern, binder::BinderContext)
    tempvar = get_temp(binder, bound_pattern)
    :($tempvar = $(code(bound_pattern)))
end

function code(bound_pattern::BoundFetchPattern)
    location = loc(bound_pattern)
    error("$(location.file):$(location.line): Internal error in Match: `code(::$(typeof(bound_pattern)))` not implemented.")
end
function code(bound_pattern::BoundFetchFieldPattern)
    # As a special case, we pretend that `Symbol` has a field that contains
    # the symbol's name.  This is because we want to be able to match against it.
    # But since there is no such field, we have to special-case it here.
    if bound_pattern.field_name == match_fieldnames(Symbol)[1]
        return :($string($(bound_pattern.input)))
    end
    :($getfield($(bound_pattern.input), $(QuoteNode(bound_pattern.field_name))))
end
function code(bound_pattern::BoundFetchIndexPattern)
    i = bound_pattern.index
    if i < 0
        i = :($length($(bound_pattern.input)) + $(i + 1))
    end
    :($getindex($(bound_pattern.input), $i))
end
function code(bound_pattern::BoundFetchRangePattern)
    index = :($(bound_pattern.first_index):(length($(bound_pattern.input)) - $(bound_pattern.from_end)))
    :($getindex($(bound_pattern.input), $(index)))
end
function code(bound_pattern::BoundFetchLengthPattern)
    :($length($(bound_pattern.input)))
end
function code(bound_pattern::BoundFetchExpressionPattern)
    code(bound_pattern.bound_expression)
end

# Return an expression that computes whether or not the pattern matches.
function lower_pattern_to_boolean(bound_pattern::BoundPattern, binder::BinderContext)
    Expr(:block, loc(bound_pattern), code(bound_pattern, binder))
end
function lower_pattern_to_boolean(bound_pattern::BoundFetchPattern, binder::BinderContext)
    # since fetches are performed purely for their side-effects, and
    # joined to the computations that require the fetched value using `and`,
    # we return `true` as the boolean value whenever we perform one.
    # (Fetches always succeed)
    Expr(:block, loc(bound_pattern), code(bound_pattern, binder), true)
end
