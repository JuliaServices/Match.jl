#
# Persistent data that we use across different patterns, to ensure the same computations
# are always represented by the same synthetic variables.  We use this during lowering
# and also during code generation, since it holds some of the context required during code
# generation (such as assertions and assignments)
#
struct BinderContext
    # The module containing the pattern, in which types appearing in the
    # pattern should be bound.
    mod::Module

    # The variable that contains the original input.
    input_variable::Symbol

    # The bindings to be used for each intermediate computations.  This maps from the
    # computation producing the value (or the pattern variable that needs a temp)
    # to the symbol for the temp holding that value.
    assignments::Dict{BoundFetchPattern, Symbol}

    # We track the type of each intermediate value.  If we don't know, then `Any`.
    types::Dict{Symbol, Type}

    # The set of type syntax forms that have asserted bindings in assertions
    asserted_types::Vector{Any}

    # Assertions that should be executed at runtime before the automaton.
    assertions::Vector{Any}

    # A dictionary used to intern AutomatonNode values in Match2Cases.
    intern::Dict # {AutomatonNode, AutomatonNode}

    # A counter used to dispense unique integers to make prettier gensyms
    num_gensyms::Ref{Int}

    function BinderContext(mod::Module)
        new(
            mod,
            gensym("input_value"),
            Dict{BoundFetchPattern, Symbol}(),
            Dict{Symbol, Type}(),
            Vector{Any}(),
            Vector{Any}(),
            Dict(), # {AutomatonNode, AutomatonNode}(),
            Ref{Int}(0)
        )
    end
end
function gensym(base::String, binder::BinderContext)::Symbol
    s = gensym("$(base)_$(binder.num_gensyms[])")
    binder.num_gensyms[] += 1
    s
end
gensym(base::String)::Symbol = Base.gensym(base)
function bind_type(location, T, input, binder)
    # bind type at macro expansion time.  It will be verified at runtime.
    bound_type = nothing
    try
        bound_type = Core.eval(binder.mod, Expr(:block, location, T))
    catch ex
        error("$(location.file):$(location.line): Could not bind `$T` as a type (due to `$ex`).")
    end

    if !(bound_type isa Type)
        error("$(location.file):$(location.line): Attempted to match non-type `$T` as a type.")
    end

    bound_type
end

function simple_name(s::Symbol)
    simple_name(string(s))
end
function simple_name(n::String)
    @assert startswith(n, "##")
    n1 = n[3:end]
    last = findlast('#', n1)
    isnothing(last) ? n1 : n1[1:prevind(n1, last)]
end

#
# Generate a fresh synthetic variable whose name hints at its purpose.
#
function gentemp(p)::Symbol
    error("not implemented: gentemp(::$(typeof(p)))")
end
function gentemp(p::BoundFetchFieldPattern)::Symbol
    gensym(string(simple_name(p.input), ".", p.field_name))
end
function gentemp(p::BoundFetchIndexPattern)::Symbol
    gensym(string(simple_name(p.input), "[", p.index, "]"))
end
function gentemp(p::BoundFetchRangePattern)::Symbol
    gensym(string(simple_name(p.input), "[", p.first_index, ":(length-", p.from_end, ")]"))
end
function gentemp(p::BoundFetchLengthPattern)::Symbol
    gensym(string("length(", simple_name(p.input), ")"))
end
function gentemp(p::BoundFetchExtractorPattern)::Symbol
    gensym(string("extract(", p.extractor, ", ", simple_name(p.input), ")"))
end

#
# The following are special bindings used to handle the point where
# a disjunction merges when and two sides have different bindings.
# In dataflow-analysis terms, this is represented by a phi function.
# This is a synthetic variable to hold the value that should be used
# to hold the value after the merge point.
#
function get_temp(binder::BinderContext, p::BoundFetchPattern)::Symbol
    temp = get!(binder.assignments, p) do; gentemp(p); end
    if haskey(binder.types, temp)
        binder.types[temp] = Union{p.type, binder.types[temp]}
    else
        binder.types[temp] = p.type
    end
    temp
end
function get_temp(binder::BinderContext, p::BoundFetchExpressionPattern)::Symbol
    temp = get!(binder.assignments, p) do
        if p.key isa Symbol
            p.key
        else
            gensym("where", binder)
        end
    end
    if haskey(binder.types, temp)
        binder.types[temp] = Union{p.type, binder.types[temp]}
    else
        binder.types[temp] = p.type
    end
    temp
end

#
#
# We restrict the struct pattern to require something that looks like
# a type name before the open paren.  This improves the diagnostics
# for error cases like `(a + b)`, which produces an analogous Expr node
# but with `+` as the operator.
#
#
is_possible_type_name(t) = false
is_possible_type_name(t::Symbol) = Base.isidentifier(t)
function is_possible_type_name(t::Expr)
    t.head == :. &&
        is_possible_type_name(t.args[1]) &&
        t.args[2] isa QuoteNode &&
        is_possible_type_name(t.args[2].value) ||
    t.head == :curly &&
        all(is_possible_type_name, t.args)
end

const unusable_variable = gensym("#a variable that was previously used on one side (only) of a disjunction");

function bind_pattern!(
    location::LineNumberNode,
    source::Any,
    input::Symbol,
    binder::BinderContext,
    assigned::ImmutableDict{Symbol, Symbol})

    if source == :_
        # wildcard pattern
        pattern = BoundTruePattern(location, source)

    elseif !(source isa Expr || source isa Symbol)
        # a constant, e.g. a regular expression, version number, raw string, etc.
        pattern = BoundIsMatchTestPattern(input, BoundExpression(location, source), false)

    elseif is_expr(source, :macrocall)
        # We permit custom string macros as long as they do not contain any unbound
        # variables.  We accomplish that simply by expanding the macro.  Macros that
        # interpolate, like lazy"", will fail because they produce a `call` rather
        # than an object.  Also, we permit users to define macros that expand to patterns.
        while is_expr(source, :macrocall)
            source = macroexpand(binder.mod, source; recursive = false)
        end
        (pattern, assigned) = bind_pattern!(location, source, input, binder, assigned)

    elseif is_expr(source, :$)
        # an interpolation
        interpolation = source.args[1]
        bound_expression = bind_expression(location, interpolation, assigned)
        pattern = BoundIsMatchTestPattern(input, bound_expression, false)

    elseif source isa Symbol
        # variable pattern (just a symbol)
        varsymbol::Symbol = source
        if haskey(assigned, varsymbol)
            # previously introduced variable.  Get the symbol holding its value
            var_value = assigned[varsymbol]
            if var_value === unusable_variable
                error("$(location.file):$(location.line): May not reuse variable name `$varsymbol` " *
                    "after it has previously been used on only one side of a disjunction.")
            end
            bound_expression = BoundExpression(
                location, source, ImmutableDict{Symbol, Symbol}(varsymbol, var_value))
            pattern = BoundIsMatchTestPattern(
                input, bound_expression,
                true) # force an equality check
        else
            # this patterns assigns the variable.
            assigned = ImmutableDict{Symbol, Symbol}(assigned, varsymbol, input)
            pattern = BoundTruePattern(location, source)
        end

    elseif is_expr(source, :(::), 1)
        # ::type
        T = source.args[1]
        T, where_clause = split_where(T, location)
        bound_type = bind_type(location, T, input, binder)
        pattern = BoundTypeTestPattern(location, T, input, bound_type)
        # Support `::T where ...` even though the where clause parses as
        # part of the type.
        pattern = join_where_clause(pattern, where_clause, location, binder, assigned)

    elseif is_expr(source, :(::), 2)
        subpattern = source.args[1]
        T = source.args[2]
        T, where_clause = split_where(T, location)
        bound_type = bind_type(location, T, input, binder)
        pattern1 = BoundTypeTestPattern(location, T, input, bound_type)
        pattern2, assigned = bind_pattern!(location, subpattern, input, binder, assigned)
        pattern = BoundAndPattern(location, source, BoundPattern[pattern1, pattern2])
        # Support `::T where ...` even though the where clause parses as
        # part of the type.
        pattern = join_where_clause(pattern, where_clause, location, binder, assigned)

    elseif is_expr(source, :call) && is_possible_type_name(source.args[1])
        # struct pattern.
        # TypeName(patterns...)
        T = source.args[1]
        subpatterns = source.args[2:end]
        len = length(subpatterns)
        named_fields = [pat.args[1] for pat in subpatterns if is_expr(pat, :kw)]
        named_count = length(named_fields)
        if named_count != length(unique(named_fields))
            error("$(location.file):$(location.line): Pattern `$source` has duplicate " *
                  "named arguments $named_fields.")
        elseif named_count != 0 && named_count != len
            error("$(location.file):$(location.line): Pattern `$source` mixes named " *
                  "and positional arguments.")
        end

        match_positionally = named_count == 0

        # bind type at macro expansion time
        bound_type = bind_type(location, T, input, binder)

        # First try the extractor, then try the struct type.
        disjuncts = BoundPattern[]

        # Check if there is an extractor method for the pattern type.
        if match_positionally
            extractor_sig = (Type{bound_type}, Val{len}, Any,)
        else
            extractor_sig = (Type{bound_type}, (Val{x} for x in sort(named_fields))..., Any,)
        end
        is_extractor = !isempty(Base.methods(Match.extract, extractor_sig))

        if is_extractor
            # Call Match.extract(T) and match the result against the tuple of subpatterns.
            # TODO remove once named tuples are supported
            @assert match_positionally error("$(location.file):$(location.line): Named arguments are not supported for extractor pattern `$source`.")
            conjuncts = BoundPattern[]
            fetch = BoundFetchExtractorPattern(location, source, input, bound_type, Any)
            extractor_temp = push_pattern!(conjuncts, binder, fetch)
            tuple_source = Expr(:tuple, subpatterns...)
            subpattern, assigned = bind_pattern!(location, tuple_source, extractor_temp, binder, assigned)
            push!(conjuncts, subpattern)
            pattern = BoundAndPattern(location, source, conjuncts)
        else
            # Use the field-by-field match.
            conjuncts = BoundPattern[]

            field_names::Tuple = match_fieldnames(bound_type)

            if match_positionally && len != length(field_names)
                # If the extractor is defined, silently fail if the field-by-field match fails.
                error("$(location.file):$(location.line): The type `$bound_type` has " *
                        "$(length(field_names)) fields but the pattern expects $len fields.")
            else
                pattern0 = BoundTypeTestPattern(location, T, input, bound_type)
                push!(conjuncts, pattern0)

                for i in 1:len
                    pat = subpatterns[i]
                    if match_positionally
                        field_name = field_names[i]
                        pattern_source = pat
                    else
                        @assert pat.head == :kw
                        field_name = pat.args[1]
                        pattern_source = pat.args[2]
                        if !(field_name in field_names)
                            error("$(location.file):$(location.line): Type `$bound_type` has " *
                                    "no field `$field_name`.")
                        end
                    end

                    field_type = nothing
                    if field_name == match_fieldnames(Symbol)[1]
                        # special case Symbol's hypothetical name field.
                        field_type = String
                    else
                        for (fname, ftype) in zip(Base.fieldnames(bound_type), Base.fieldtypes(bound_type))
                            if fname == field_name
                                field_type = ftype
                                break
                            end
                        end
                    end
                    @assert field_type !== nothing

                    fetch = BoundFetchFieldPattern(location, pattern_source, input, field_name, field_type)
                    field_temp = push_pattern!(conjuncts, binder, fetch)
                    bound_subpattern, assigned = bind_pattern!(
                        location, pattern_source, field_temp, binder, assigned)
                    push!(conjuncts, bound_subpattern)
                end
            end

            pattern = BoundAndPattern(location, source, conjuncts)
        end

    elseif is_expr(source, :(&&), 2)
        # conjunction: `(a && b)` where `a` and `b` are patterns.
        subpattern1 = source.args[1]
        subpattern2 = source.args[2]
        bp1, assigned = bind_pattern!(location, subpattern1, input, binder, assigned)
        bp2, assigned = bind_pattern!(location, subpattern2, input, binder, assigned)
        pattern = BoundAndPattern(location, source, BoundPattern[bp1, bp2])

    elseif is_expr(source, :call, 3) && source.args[1] == :&
        # conjunction: `(a & b)` where `a` and `b` are patterns.
        return bind_pattern!(location, Expr(:(&&), source.args[2], source.args[3]), input, binder, assigned)

    elseif is_expr(source, :(||), 2)
        # disjunction: `(a || b)` where `a` and `b` are patterns.
        subpattern1 = source.args[1]
        subpattern2 = source.args[2]
        bp1, assigned1 = bind_pattern!(location, subpattern1, input, binder, assigned)
        bp2, assigned2 = bind_pattern!(location, subpattern2, input, binder, assigned)

        # compute the common assignments.
        both = intersect(keys(assigned1), keys(assigned2))
        assigned = ImmutableDict{Symbol, Symbol}()
        for key in both
            v1 = assigned1[key]
            v2 = assigned2[key]
            if v1 == v2
                assigned = ImmutableDict{Symbol, Symbol}(assigned, key, v1)
            elseif v1 === unusable_variable || v2 === unusable_variable
                # A previously unusable variable remains unusable
                assigned = ImmutableDict{Symbol, Symbol}(assigned, key, unusable_variable)
            else
                # Every phi gets its own distinct variable.  That ensures we do not
                # share them between patterns.
                temp = gensym(string("phi_", key), binder)
                if v1 != temp
                    bound_expression = BoundExpression(location, v1, ImmutableDict{Symbol, Symbol}(key, v1))
                    save = BoundFetchExpressionPattern(bound_expression, temp, Any)
                    bp1 = BoundAndPattern(location, source, BoundPattern[bp1, save])
                end
                if v2 != temp
                    bound_expression = BoundExpression(location, v2, ImmutableDict{Symbol, Symbol}(key, v2))
                    save = BoundFetchExpressionPattern(bound_expression, temp, Any)
                    bp2 = BoundAndPattern(location, source, BoundPattern[bp2, save])
                end
                assigned = ImmutableDict{Symbol, Symbol}(assigned, key, temp)
            end
        end

        # compute variables that were assigned on only one side of the disjunction and mark
        # them (by using a designated value in `assigned`) so we can give an error message
        # when a variable that is defined on only one side of a disjunction is used again
        # later in the enclosing pattern.
        one_only = setdiff(union(keys(assigned1), keys(assigned2)), both)
        for key in one_only
            assigned = ImmutableDict{Symbol, Symbol}(assigned, key, unusable_variable)
        end

        pattern = BoundOrPattern(location, source, BoundPattern[bp1, bp2])

    elseif is_expr(source, :call, 3) && source.args[1] == :|
        # disjunction: `(a | b)` where `a` and `b` are patterns.
        return bind_pattern!(location, Expr(:(||), source.args[2], source.args[3]), input, binder, assigned)

    elseif is_expr(source, :tuple) || is_expr(source, :vect)
        # array or tuple
        subpatterns = source.args

        if any(arg -> is_expr(arg, :parameters), subpatterns)
            error("$(location.file):$(location.line): Cannot mix named and positional parameters in pattern `$source`.")
        end

        splat_count = count(s -> is_expr(s, :...), subpatterns)
        if splat_count > 1
            error("$(location.file):$(location.line): More than one `...` in " *
                  "pattern `$source`.")
        end

        # produce a check that the input is an array (or tuple)
        patterns = BoundPattern[]
        base = source.head == :vect ? AbstractArray : Tuple
        pattern0 = BoundTypeTestPattern(location, base, input, base)
        push!(patterns, pattern0)
        len = length(subpatterns)

        # produce a check that the length of the input is sufficient
        length_temp = push_pattern!(patterns, binder,
            BoundFetchLengthPattern(location, source, input, Any))
        check_length =
            if splat_count != 0
                BoundRelationalTestPattern(
                    location, source, length_temp, :>=, length(subpatterns)-1)
            else
                bound_expression = BoundExpression(location, length(subpatterns))
                BoundIsMatchTestPattern(length_temp, bound_expression, true)
            end
        push!(patterns, check_length)

        seen_splat = false
        for (i, subpattern) in enumerate(subpatterns)
            if is_expr(subpattern, :...)
                @assert length(subpattern.args) == 1
                @assert !seen_splat
                seen_splat = true
                range_temp = push_pattern!(patterns, binder,
                    BoundFetchRangePattern(location, subpattern, input, i, len-i, Any))
                patterni, assigned = bind_pattern!(
                    location, subpattern.args[1], range_temp, binder, assigned)
                push!(patterns, patterni)
            else
                index = seen_splat ? (i - len - 1) : i
                index_temp = push_pattern!(patterns, binder,
                    BoundFetchIndexPattern(location, subpattern, input, index, Any))
                patterni, assigned = bind_pattern!(
                    location, subpattern, index_temp, binder, assigned)
                push!(patterns, patterni)
            end
        end
        pattern = BoundAndPattern(location, source, patterns)

    elseif is_expr(source, :where, 2)
        # subpattern where guard
        subpattern = source.args[1]
        guard = source.args[2]
        pattern0, assigned = bind_pattern!(location, subpattern, input, binder, assigned)
        pattern1 = shred_where_clause(guard, false, location, binder, assigned)
        pattern = BoundAndPattern(location, source, BoundPattern[pattern0, pattern1])

    elseif is_expr(source, :if, 2)
        # if expr end
        if !is_empty_block(source.args[2])
            error("$(location.file):$(location.line): Unrecognized @match guard syntax: `$source`.")
        end
        guard = source.args[1]
        pattern = shred_where_clause(guard, false, location, binder, assigned)

    elseif is_expr(source, :call) && source.args[1] == :(:) && length(source.args) in 3:4
        # A range pattern.  We depend on the Range API to make sense of it.
        lower = source.args[2]
        upper = source.args[3]
        step = (length(source.args) == 4) ? source.args[4] : nothing
        if upper isa Expr || upper isa Symbol ||
            lower isa Expr || lower isa Symbol ||
            step isa Expr || step isa Symbol
            error("$(location.file):$(location.line): Non-constant range pattern: `$source`.")
        end
        pattern = BoundIsMatchTestPattern(input, BoundExpression(location, source), false)

    else
        error("$(location.file):$(location.line): Unrecognized pattern syntax `$(pretty(source))`.")
    end

    return (pattern, assigned)
end

function push_pattern!(patterns::Vector{BoundPattern}, binder::BinderContext, pat::BoundFetchPattern)
    push!(patterns, pat)
    get_temp(binder, pat)
end

function split_where(T, location)
    type = T
    where_clause = nothing
    while is_expr(type, :where)
        where_clause = (where_clause === nothing) ? type.args[2] : :($(type.args[2]) && $where_clause)
        type = type.args[1]
    end

    if !is_possible_type_name(type)
        error("$(location.file):$(location.line): Invalid type name: `$type`.")
    end

    return (type, where_clause)
end

function join_where_clause(pattern, where_clause, location, binder, assigned)
    if where_clause === nothing
        return pattern
    else
        pattern1 = shred_where_clause(where_clause, false, location, binder, assigned)
        return BoundAndPattern(location, where_clause, BoundPattern[pattern, pattern1])
    end
end

"""
    match_fieldnames(type::Type)

Return a tuple containing the ordered list of the names (as Symbols) of fields that
can be matched either nominally or positionally.  This list should exclude synthetic
fields that are produced by packages such as Mutts and AutoHashEqualsCached.  This
function may be overridden by the client to hide fields that should not be matched.
"""
function match_fieldnames(type::Type)
    Base.fieldnames(type)
end

# For the purposes of pattern-matching, we pretend that `Symbol` has a single field.
const symbol_field_name = Symbol("«name(::Symbol)»")
match_fieldnames(::Type{Symbol}) = (symbol_field_name,)

#
# Shred a `where` clause into its component parts, conjunct by conjunct.  If necessary,
# we push negation operators down.  This permits us to share the parts of a where clause
# between different rules.
#
function shred_where_clause(
    guard::Any,
    inverted::Bool,
    location::LineNumberNode,
    binder::BinderContext,
    assigned::ImmutableDict{Symbol, Symbol})::BoundPattern
    if @capture(guard, !g_)
        return shred_where_clause(g, !inverted, location, binder, assigned)
    elseif @capture(guard, g1_ && g2_) || @capture(guard, g1_ || g2_)
        left = shred_where_clause(g1, inverted, location, binder, assigned)
        right = shred_where_clause(g2, inverted, location, binder, assigned)
        # DeMorgan's law:
        #     `!(a && b)` => `!a || !b`
        #     `!(a || b)` => `!a && !b`
        result_type = (inverted == (guard.head == :&&)) ? BoundOrPattern : BoundAndPattern
        return result_type(location, guard, BoundPattern[left, right])
    else
        bound_expression = bind_expression(location, guard, assigned)
        fetch = BoundFetchExpressionPattern(bound_expression, nothing, Any)
        temp = get_temp(binder, fetch)
        test = BoundWhereTestPattern(location, guard, temp, inverted)
        return BoundAndPattern(location, guard, BoundPattern[fetch, test])
    end
end

#
# getvars
#
# get all symbols in an expression
#
getvars(e)         = Set{Symbol}()
getvars(e::Symbol) = startswith(string(e), '@') ? Set{Symbol}() : push!(Set{Symbol}(), e)
getvars(e::Expr)   = getvars(is_expr(e, :call) ? e.args[2:end] : e.args)
getvars(es::AbstractArray) = union(Set{Symbol}(), [getvars(e) for e in es]...)

#
# Produce a `BoundExpression` object for the given expression.  This is used to
# determine the set of variable bindings that are used in the expression, and to
# simplify code generation.
#
function bind_expression(location::LineNumberNode, expr, assigned::ImmutableDict{Symbol, Symbol})
    if is_expr(expr, :(...))
        error("$(location.file):$(location.line): Splatting not supported in interpolation: `$expr`.")
    end

    # determine the variables *actually* used in the expression
    used = getvars(expr)

    # we sort the used variables by name so that we have a deterministic order
    # that will make it more likely we can share the resulting expression.
    used = sort(collect(intersect(keys(assigned), used)))

    assignments = Expr(:block)
    new_assigned = ImmutableDict{Symbol, Symbol}()
    for v in used
        tmp = get(assigned, v, nothing)
        @assert tmp !== nothing
        if tmp === unusable_variable
            # The user is attempting to use a variable that was defined on only
            # one side of a disjunction.  That is an error.
            error("$(location.file):$(location.line): The pattern variable `$v` cannot be used because it was defined on only one side of a disjunction.")
        end
        push!(assignments.args, Expr(:(=), v, tmp))
        new_assigned = ImmutableDict(new_assigned, v => tmp)
    end

    return BoundExpression(location, expr, new_assigned)
end

is_empty_block(x) = is_expr(x, :block) && all(a -> a isa LineNumberNode, x.args)

#
# Bind a case.
#
function bind_case(
    case_number::Int,
    location::LineNumberNode,
    case,
    predeclared_temps,
    binder::BinderContext)::BoundCase
    while true
        # do some rewritings if needed
        if is_expr(case, :macrocall)
            # expand top-level macros only
            case = macroexpand(binder.mod, case, recursive=false)

        elseif is_expr(case, :tuple, 2) && is_case(case.args[2]) && is_expr(case.args[2].args[2], :if, 2)
            # rewrite `pattern, if guard end => result`, which parses as
            # `pattern, (if guard end => result)`
            # to `(pattern, if guard end) => result`
            # so that the guard is part of the pattern.
            pattern = case.args[1]
            if_guard = case.args[2].args[2]
            result = case.args[2].args[3]
            case = :(($pattern, $if_guard) => $result)

        elseif is_case(case)
            # rewrite `(pattern, if guard end) => result`
            # to `(pattern where guard) => result`
            pattern = case.args[2]
            if is_expr(pattern, :tuple, 2) && is_expr(pattern.args[2], :if, 2)
                if_guard = pattern.args[2]
                if !is_empty_block(if_guard.args[2])
                    error("$(location.file):$(location.line): Unrecognized @match guard syntax: `$if_guard`.")
                end
                pattern = pattern.args[1]
                guard = if_guard.args[1]
                result = case.args[3]
                case = :(($pattern where $guard) => $result)
            end
            break

        else
            error("$(location.file):$(location.line): Unrecognized @match case syntax: `$case`.")
        end
    end

    @assert is_case(case)
    pattern = case.args[2]
    result = case.args[3]
    (pattern, result) = adjust_case_for_return_macro(binder.mod, location, pattern, result, predeclared_temps)
    bound_pattern, assigned = bind_pattern!(
        location, pattern, binder.input_variable, binder, ImmutableDict{Symbol, Symbol}())
    result_expression = bind_expression(location, result, assigned)
    return BoundCase(case_number, location, pattern, bound_pattern, result_expression)
end
