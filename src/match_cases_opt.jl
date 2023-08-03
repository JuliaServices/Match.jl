#
# Build the decision automaton and return its entry point.
#
function build_automaton_core(
    value,
    source_cases::Vector{Any},
    location::LineNumberNode,
    predeclared_temps,
    binder::BinderContext)::AutomatonNode
    cases = BoundCase[]
    for case in source_cases
        if case isa LineNumberNode
            location = case
        else
            bound_case::BoundCase = bind_case(length(cases) + 1, location, case, predeclared_temps, binder)
            bound_case = simplify(bound_case, binder)
            push!(cases, bound_case)
        end
    end

    # Track the set of reachable cases (by index)
    reachable = Set{Int}()

    # Make an entry point for the automaton
    entry = AutomatonNode(cases)

    # If the value had a type annotation, then we can use that to
    # narrow down the cases that we need to consider.
    input_type = Any
    if is_expr(value, :(::), 2)
        type = value.args[2]
        try
            input_type = bind_type(location, type, binder.input_variable, binder)
        catch
            # If we don't understand the type annotation, then we'll just ignore it.
        end
        binder.types[binder.input_variable] = input_type
        if input_type !== Any
            filter = BoundTypeTestPattern(location, type, binder.input_variable, input_type)
            entry = remove(filter, true, entry, binder)
        end
    end
    binder.types[binder.input_variable] = input_type

    # Build the decision automaton with the given entry point
    work_queue = Set{AutomatonNode}([entry])
    while !isempty(work_queue)
        node = pop!(work_queue)
        if node.action isa Nothing
            set_next!(node, binder)
            @assert node.action !== nothing
            @assert node.next !== nothing
            if node.action isa BoundCase
                push!(reachable, node.action.case_number)
            end
            union!(work_queue, successors(node))
        end
    end

    # Warn if there were any unreachable cases
    for i in 1:length(cases)
        if !(i in reachable)
            case = cases[i]
            loc = case.location
            @warn("$(loc.file):$(loc.line): Case $(case.case_number): `$(case.pattern_source) =>` is not reachable.")
        end
    end

    entry
end

#
# Generate all of the code given the entry point
#
function generate_code(top_down_nodes::Vector{DeduplicatedAutomatonNode}, @nospecialize(value), location::LineNumberNode, binder::BinderContext)
    result_variable = gensym("match_result")
    result_label = gensym("completed")
    emit = Any[location, :($(binder.input_variable) = $value)]

    # put the first node last so it will be the first to be emitted
    reverse!(top_down_nodes)
    togen = top_down_nodes # now it's in the right order to consume from the end

    # Because we are producing code in a top-down topologically-sorted order,
    # all of the `@goto`s that we emit are forward.  So we are guaranteed to emit
    # the `@goto` (and calling `label!`) before we hit the node where we need the `@label`.
    labels = IdDict{DeduplicatedAutomatonNode, Symbol}()
    function label!(code::DeduplicatedAutomatonNode)
        get!(() -> gensym("label", binder), labels, code)
    end

    while !isempty(togen)
        node = pop!(togen)
        if node in keys(labels)
            push!(emit, :(@label $(labels[node])))
        end
        action = node.action
        if action isa BoundCase
            # We've matched a pattern.
            push!(emit, loc(action))
            push!(emit, :($result_variable = $(code(action.result_expression))))
            push!(emit, :(@goto $result_label))
        elseif action isa BoundFetchPattern
            push!(emit, loc(action))
            push!(emit, code(action, binder))
            (next::DeduplicatedAutomatonNode,) = node.next
            if last(togen) != next
                # We need a `goto`, since it isn't the next thing we can fall into.
                # This call to `label` sets up the label in the `labels` map to be
                # produced when we emit the target node.
                push!(emit, :(@goto $(label!(next))))
            end
        elseif action isa BoundTestPattern
            push!(emit, loc(action))
            next_true, next_false = node.next
            push!(emit, :($(code(action, binder)) || @goto $(label!(next_false))))
            if last(togen) != next_true
                # we need a `goto`, since it isn't the next thing we can fall into.
                push!(emit, :(@goto $(label!(next_true))))
            end
        elseif action isa Expr
            push!(emit, action)
        else
            error("this node ($(typeof(action))) is believed unreachable")
        end
    end

    push!(emit, :(@label $result_label))
    push!(emit, result_variable)
    Expr(:block, binder.assertions..., emit...)
end

#
# Build the whole decision automaton from the syntax for the value and body
#
function build_automaton(location::LineNumberNode, mod::Module, @nospecialize(value), body)
    if is_case(body)
        # previous version of @match supports `@match(expr, pattern => value)`
        body = Expr(:block, body)
    end
    if is_expr(body, :block)
        source_cases = body.args
    else
        error("$(location.file):$(location.line): Unrecognized @match block syntax: `$body`.")
    end

    binder = BinderContext(mod)
    predeclared_temps = Any[]
    entry = build_automaton_core(value, source_cases, location, predeclared_temps, binder)
    return entry, predeclared_temps, binder
end

#
# Build the whole decision automaton from the syntax for the value and body,
# optimize it, and return the resulting set of nodes along with the binder.
#
function build_deduplicated_automaton(location::LineNumberNode, mod::Module, value, body)
    entry, predeclared_temps, binder = build_automaton(location::LineNumberNode, mod::Module, value, body)
    top_down_nodes = deduplicate_automaton(entry, binder)
    return top_down_nodes, predeclared_temps, binder
end

#
# Compute and record the next action for the given node.
#
function set_next!(node::AutomatonNode, binder::BinderContext)
    @assert node.action === nothing
    @assert node.next === nothing

    action::Union{BoundCase, BoundPattern, Expr} = next_action(node, binder)
    next::Union{Tuple{}, Tuple{AutomatonNode}, Tuple{AutomatonNode, AutomatonNode}} =
        make_next(node, action, binder)
    node.action = action
    node.next = next
    @assert !(node.next isa Nothing)
end


#
# Compute the next action for the given decision automaton node.  We take the
# simple approach of just doing the next thing on the list of the first pattern
# that might match (the left-to-right "heusristic").  We might use different
# heuristics to do better, but not likely by more than a few percent except
# in machine-generated code.
# See https://www.cs.tufts.edu/~nr/cs257/archive/norman-ramsey/match.pdf for details.
# See https://gist.github.com/gafter/145db4a2282296bdaa08e0a0dcce9217 for an example
# of machine-generated pattern-matching code that can cause an explosion of generated
# code size.
#
function next_action(
    node::AutomatonNode,
    binder::BinderContext)::Union{BoundCase, BoundPattern, Expr}
    if isempty(node.cases)
        # cases have been exhausted.  Return code to throw a match failure.
        return :($throw($MatchFailure($(binder.input_variable))))
    end
    first_case = node.cases[1]
    if first_case.pattern isa BoundTruePattern
        # case has been satisfied.  Return it as our destination.
        return first_case
    end
    return next_action(first_case.pattern)
end
next_action(pattern::BoundPattern) = pattern
function next_action(pattern::Union{BoundFalsePattern, BoundTruePattern})
    error("unreachable - a $(typeof(pattern)) cannot be the next action")
end
function next_action(pattern::Union{BoundAndPattern, BoundOrPattern})
    return next_action(pattern.subpatterns[1])
end

#
# Given an action, make the "next" result, which is the action or successor
# node of the decision automaton.
#
function make_next(
    node::AutomatonNode,
    action::Union{BoundCase, Expr},
    binder::BinderContext)
    return ()
end
function make_next(
    node::AutomatonNode,
    action::BoundPattern,
    binder::BinderContext)
    error("pattern cannot be the next action: $(typeof(action))")
end
function intern(node::AutomatonNode, binder::BinderContext)
    get!(binder.intern, node, node)
end
function make_next(
    node::AutomatonNode,
    action::BoundFetchPattern,
    binder::BinderContext)::Tuple{AutomatonNode}
    succ = remove(action, node, binder)
    succ = intern(succ, binder)
    return (succ,)
end

# When a test occurs, there are two subsequent nodes, depending on the outcome of the test.
function make_next(
    node::AutomatonNode,
    action::BoundTestPattern,
    binder::BinderContext)::Tuple{AutomatonNode, AutomatonNode}
    true_next = remove(action, true, node, binder)
    false_next = remove(action, false, node, binder)
    true_next = intern(true_next, binder)
    false_next = intern(false_next, binder)
    return (true_next, false_next)
end

# The next code point is the same but without the action, since it has been done.
function remove(action::BoundFetchPattern, node::AutomatonNode, binder::BinderContext)::AutomatonNode
    cases = map(c -> remove(action, c, binder), node.cases)
    succ = AutomatonNode(cases)

    # If we know the type of the fetched value, we can assert that in downstream code.
    bound_type = action.type
    if bound_type !== Any
        temp = get_temp(binder, action)
        filter = BoundTypeTestPattern(loc(action), source(action), temp, bound_type)
        succ = remove(filter, true, succ, binder)
    end
    succ
end
function remove(action::BoundTestPattern, sense::Bool, node::AutomatonNode, binder::BinderContext)::AutomatonNode
    cases = map(c -> remove(action, sense, c, binder), node.cases)
    return AutomatonNode(cases)
end

function remove(action::BoundTestPattern, action_result::Bool, case::BoundCase, binder::BinderContext)::BoundCase
    with_pattern(case, remove(action, action_result, case.pattern, binder))
end
function remove(action::BoundFetchPattern, case::BoundCase, binder::BinderContext)::BoundCase
    with_pattern(case, remove(action, case.pattern, binder))
end

#
# Remove the given action from a pattern.
#
remove(action::BoundFetchPattern, pattern::BoundPattern, binder::BinderContext)::BoundPattern = pattern
remove(action::BoundTestPattern, action_result::Bool, pattern::BoundPattern, binder::BinderContext)::BoundPattern = pattern
function remove(action::BoundFetchPattern, pattern::BoundFetchPattern, binder::BinderContext)::BoundPattern
    return (action == pattern) ? BoundTruePattern(loc(pattern), source(pattern)) : pattern
end
function remove(action::BoundFetchPattern, pattern::Union{BoundAndPattern,BoundOrPattern}, binder::BinderContext)::BoundPattern
    subpatterns = collect(BoundPattern, map(p -> remove(action, p, binder), pattern.subpatterns))
    return (typeof(pattern))(loc(pattern), source(pattern), subpatterns)
end
function remove(action::BoundTestPattern, action_result::Bool, pattern::BoundTestPattern, binder::BinderContext)::BoundPattern
    return (action == pattern) ? BoundBoolPattern(loc(pattern), source(pattern), action_result) : pattern
end
function remove(action::BoundIsMatchTestPattern, action_result::Bool, pattern::BoundIsMatchTestPattern, binder::BinderContext)::BoundPattern
    if action.input != pattern.input || action.force_equality != pattern.force_equality
        return pattern
    end
    if isequal(action.bound_expression, pattern.bound_expression)
        return BoundBoolPattern(loc(pattern), source(pattern), action_result)
    end

    # As a special case, if the input variable is of type Bool, then we know that true and false
    # are the only values it can hold.
    type = get!(() -> Any, binder.types, action.input)
    if type == Bool && action.bound_expression.source isa Bool && pattern.bound_expression.source isa Bool
        @assert action.bound_expression.source != pattern.bound_expression.source # because we already checked for equality
        # If the one succeeded, then the other one fails
        return BoundBoolPattern(loc(pattern), source(pattern), !action_result)
    end

    return pattern
end
function remove(action::BoundTestPattern, action_result::Bool, pattern::Union{BoundAndPattern,BoundOrPattern}, binder::BinderContext)::BoundPattern
    subpatterns = collect(BoundPattern, map(p -> remove(action, action_result, p, binder), pattern.subpatterns))
    return (typeof(pattern))(loc(pattern), source(pattern), subpatterns)
end
function remove(action::BoundWhereTestPattern, action_result::Bool, pattern::BoundWhereTestPattern, binder::BinderContext)::BoundPattern
    # Two where tests can be related by being the inverse of each other.
    action.input == pattern.input || return pattern
    replacement_value = (action.inverted == pattern.inverted) == action_result
    return BoundBoolPattern(loc(pattern), source(pattern), replacement_value)
end
function remove(action::BoundTypeTestPattern, action_result::Bool, pattern::BoundTypeTestPattern, binder::BinderContext)::BoundPattern
    # Knowing the result of one type test can give information about another.  For
    # example, if you know `x` is a `String`, then you know that it isn't an `Int`.
    if (action == pattern)
        return BoundBoolPattern(loc(pattern), source(pattern), action_result)
    elseif action.input != pattern.input
        return pattern
    elseif action_result
        # the type test succeeded.
        if action.type <: pattern.type
            return BoundTruePattern(loc(pattern), source(pattern))
        elseif pattern.type <: action.type
            # we are asking about a narrower type - result unknown
            return pattern
        else
            # Since Julia does not support multiple inheritance, if the two types
            # are not related by inheritance, then no types that implement both will
            # ever come into existence.
            @assert typeintersect(pattern.type, action.type) == Base.Bottom

            # their intersection is empty, so it cannot be pattern.type
            return BoundFalsePattern(loc(pattern), source(pattern))
        end
    else
        # the type test failed.
        if action.type <: pattern.type
            # we are asking about a wider type - result unknown
            return pattern
        elseif pattern.type <: action.type
            # if it wasn't the wider type, then it won't be the narrower type
            return BoundFalsePattern(loc(pattern), source(pattern))
        else
            return pattern
        end
    end
end

#
# Simplify a case by removing fetch operations whose results are not used.
#
function simplify(case::BoundCase, binder::BinderContext)::BoundCase
    required_temps = Set(values(case.result_expression.assignments))
    simplified_pattern = simplify(case.pattern, required_temps, binder)
    return with_pattern(case, simplified_pattern)
end

#
# Simplify a pattern by removing fetch operations whose results are not used.
#
function simplify(pattern::BoundPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    push!(required_temps, pattern.input)
    pattern
end
function simplify(pattern::Union{BoundTruePattern, BoundFalsePattern}, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    pattern
end
function simplify(pattern::BoundFetchPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    temp = get_temp(binder, pattern)
    if temp in required_temps
        pop!(required_temps, temp)
        push!(required_temps, pattern.input)
        pattern
    else
        BoundTruePattern(loc(pattern), source(pattern))
    end
end
function simplify(pattern::BoundFetchExpressionPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    temp = get_temp(binder, pattern)
    if temp in required_temps
        pop!(required_temps, temp)
        for (v, t) in pattern.bound_expression.assignments
            push!(required_temps, t)
        end
        pattern
    else
        BoundTruePattern(loc(pattern), source(pattern))
    end
end
function simplify(pattern::BoundIsMatchTestPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    push!(required_temps, pattern.input)
    for (v, t) in pattern.bound_expression.assignments
        push!(required_temps, t)
    end
    pattern
end
function simplify(pattern::BoundAndPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    subpatterns = BoundPattern[]
    for p in reverse(pattern.subpatterns)
        simplified = simplify(p, required_temps, binder)
        push!(subpatterns, simplified)
    end
    BoundAndPattern(loc(pattern), source(pattern), BoundPattern[reverse(subpatterns)...])
end
function simplify(pattern::BoundOrPattern, required_temps::Set{Symbol}, binder::BinderContext)::BoundPattern
    subpatterns = BoundPattern[]
    new_required_temps = Set{Symbol}()
    for p in reverse(pattern.subpatterns)
        rt = copy(required_temps)
        push!(subpatterns, simplify(p, rt, binder))
        union!(new_required_temps, rt)
    end
    empty!(required_temps)
    union!(required_temps, new_required_temps)
    BoundOrPattern(loc(pattern), source(pattern), BoundPattern[reverse(subpatterns)...])
end

#
# Some useful macros for testing and diagnosing the decision automaton.
#

# Return the count of the number of nodes that would be generated by the match,
# but otherwise does not generate any code for the match.
macro match_count_nodes(value, body)
    top_down_nodes, predeclared_temps, binder = build_deduplicated_automaton(__source__, __module__, value, body)
    length(top_down_nodes)
end

# Print the automaton (one line per node) to a given io channel
macro match_dump(io, value, body)
    handle_match_dump(__source__, __module__, io, value, body)
end
# Print the automaton (one line per node) to stdout
macro match_dump(value, body)
    handle_match_dump(__source__, __module__, stdout, value, body)
end
# Print the automaton (verbose) to a given io channel
macro match_dumpall(io, value, body)
    handle_match_dump_verbose(__source__, __module__, io, value, body)
end
# Print the automaton (verbose) to stdout
macro match_dumpall(value, body)
    handle_match_dump_verbose(__source__, __module__, stdout, value, body)
end

function handle_match_dump(__source__, __module__, io, value, body)
    top_down_nodes, predeclared_temps, binder = build_deduplicated_automaton(__source__, __module__, value, body)
    esc(:($dumpall($io, $top_down_nodes, $binder, false)))
end

function handle_match_dump_verbose(__source__, __module__, io, value, body)
    entry, predeclared_temps, binder = build_automaton(__source__, __module__, value, body)
    top_down_nodes = reachable_nodes(entry)

    esc(quote
        # print the dump of the decision automaton before deduplication
        $dumpall($io, $top_down_nodes, $binder, true)
        # but return the count of deduplicated nodes.
        $length($deduplicate_automaton($entry, $binder))
    end)
end

#
# Implementation of `@match value begin ... end`
#
function handle_match_cases(location::LineNumberNode, mod::Module, value, body)
    top_down_nodes, predeclared_temps, binder = build_deduplicated_automaton(location, mod, value, body)
    result = generate_code(top_down_nodes, value, location, binder)
    @assert is_expr(result, :block)

    # We use a `let` to ensure consistent closed scoping
    result = Expr(:let, Expr(:block, predeclared_temps...), result)
    esc(result)
end
