#
# Pretty-printing utilities to simplify debugging of this package
#

pretty(io::IO, x::Any) = print(io, x)
function pretty(x::Any)
    io = IOBuffer()
    pretty(io, x)
    String(take!(io))
end

function dumpall(io::IO, all::Vector{T}, binder::BinderContext, long::Bool) where { T <: AbstractAutomatonNode }
    # Make a map from each node to its index
    id = IdDict{T, Int}(map(((i,s),) -> s => i, enumerate(all))...)
    print(io, "Decision Automaton: ($(length(all)) nodes) input ")
    pretty(io, binder.input_variable)
    println(io)
    for node in all
        pretty(io, node, binder, id, long)
        println(io)
    end
    println(io, "end # of automaton")
    length(all)
end

# Pretty-print either an AutomatonNode or a DeduplicatedAutomatonNode
function pretty(
    io::IO,
    node::T,
    binder::BinderContext,
    id::IdDict{T, Int},
    long::Bool = true) where { T <: AbstractAutomatonNode }
    print(io, name(node, id))
    if long && hasfield(T, :cases)
        println(io)
        for case in node.cases
            print(io, "  ")
            pretty(io, case, binder)
        end
    end
    action = node.action
    long && print(io, "   ")
    if action isa BoundCase
        print(io, " MATCH ", action.case_number, " with value ")
        pretty(io, action.result_expression)
    elseif action isa BoundPattern
        if action isa BoundTestPattern
            print(io, " TEST ")
        elseif action isa BoundFetchPattern
            print(io, " FETCH ")
        end
        pretty(io, action, binder)
    elseif action isa Expr
        print(io, " FAIL ")
        pretty(io, action)
    end
    next = node.next
    if next isa Tuple{T}
        fall_through = id[next[1]] == id[node] + 1
        if long || !fall_through
            long && print(io, "\n   ")
            print(io, " NEXT: $(name(next[1], id))")
            if id[next[1]] == id[node] + 1
                print(io, " (fall through)")
            end
        end
    elseif next isa Tuple{T, T}
        fall_through = id[next[1]] == id[node] + 1
        if long || !fall_through
            long && print(io, "\n   ")
            print(io, " THEN: $(name(next[1], id))")
            if id[next[1]] == id[node] + 1
                print(io, " (fall through)")
            end
            long && println(io)
        end
        long && print(io, "   ")
        print(io, " ELSE: $(name(next[2], id))")
    end
end

pretty(io::IO, p::BoundPattern, binder::BinderContext) = pretty(io, p)
function pretty(io::IO, p::BoundFetchPattern)
    error("pretty-printing a BoundFetchPattern requires a BinderContext")
end
function pretty(io::IO, p::Union{BoundOrPattern, BoundAndPattern}, binder::BinderContext)
    op = (p isa BoundOrPattern) ? "||" : "&&"
    print(io, "(")
    first = true
    for sp in p.subpatterns
        first || print(io, " ", op, " ")
        first = false
        pretty(io, sp, binder)
    end
    print(io, ")")
end
function pretty(io::IO, p::BoundFetchPattern, binder::BinderContext)
    temp = get_temp(binder, p)
    pretty(io, temp)
    print(io, " := ")
    pretty(io, p)
end
function pretty(io::IO, s::Symbol)
    print(io, pretty_name(s))
end
function pretty_name(s::Symbol)
    s = string(s)
    if startswith(s, "##")
        string("«", simple_name(s), "»")
    else
        s
    end
end
struct FrenchName; s::Symbol; end
Base.show(io::IO, x::FrenchName) = print(io, pretty_name(x.s))
function pretty(io::IO, expr::Expr)
    b = MacroTools.prewalk(MacroTools.rmlines, expr)
    c = MacroTools.prewalk(MacroTools.unblock, b)
    print(io, MacroTools.postwalk(c) do var
        (var isa Symbol) ? Symbol(FrenchName(var)) : var
    end)
end

function pretty(io::IO, case::BoundCase, binder::BinderContext)
    print(io, case.case_number, ": ")
    pretty(io, case.pattern, binder)
    print(io, " => ")
    pretty(io, case.result_expression)
    println(io)
end

pretty(io::IO, ::BoundTruePattern) = print(io, "true")
pretty(io::IO, ::BoundFalsePattern) = print(io, "false")
function pretty(io::IO, e::BoundExpression)
    if !isempty(e.assignments)
        pretty(io, e.assignments)
        print(io, " ")
    end
    pretty(io, e.source)
end
function pretty(io::IO, assignments::ImmutableDict{Symbol, Symbol})
    print(io, "[")
    for (i, (k, v)) in enumerate(assignments)
        i > 1 && print(io, ", ")
        pretty(io, k)
        print(io, " => ")
        pretty(io, v)
    end
    print(io, "]")
end
function pretty(io::IO, p::BoundIsMatchTestPattern)
    print(io, p.force_equality ? "isequal(" : "@ismatch(")
    pretty(io, p.input)
    print(io, ", ")
    pretty(io, p.bound_expression)
    print(io, ")")
end
function pretty(io::IO, p::BoundRelationalTestPattern)
    pretty(io, p.input)
    print(io, " ", p.relation, " ")
    pretty(io, p.value)
end
function pretty(io::IO, p::BoundWhereTestPattern)
    p.inverted && print(io, "!")
    pretty(io, p.input)
end
function pretty(io::IO, p::BoundTypeTestPattern)
    pretty(io, p.input)
    print(io, " isa ", p.type)
end
function pretty(io::IO, p::BoundFetchFieldPattern)
    pretty(io, p.input)
    print(io, ".", p.field_name)
end
function pretty(io::IO, p::BoundFetchIndexPattern)
    pretty(io, p.input)
    print(io, "[", p.index, "]")
end
function pretty(io::IO, p::BoundFetchRangePattern)
    pretty(io, p.input)
    print(io, "[", p.first_index, ":(length(", pretty_name(p.input), ")-", p.from_end, ")]")
end
function pretty(io::IO, p::BoundFetchLengthPattern)
    print(io, "length(")
    pretty(io, p.input)
    print(io, ")")
end
function pretty(io::IO, p::BoundFetchExpressionPattern)
    pretty(io, p.bound_expression)
end
