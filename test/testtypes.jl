
const get_current_exceptions = (VERSION >= v"1.7") ? current_exceptions : Base.catch_stack

macro where_thrown()
    quote
        stack = $get_current_exceptions()
        l = last(stack)
        trace = stacktrace(l[2])
        trace[1]
    end
end

# Quote the syntax without interpolation.
macro no_escape_quote(x)
    QuoteNode(x)
end

struct True; end

struct Foo
    x
    y
end

# Extractors
struct Polar end
function Match.extract(::Type{Polar}, ::Val{2}, p::Foo)
    return (sqrt(p.x^2 + p.y^2), atan(p.y, p.x))
end

struct Diff end
function Match.extract(::Type{Diff}, ::Val{1}, p::Foo)
    return p.x >= p.y ? (p.x - p.y,) : nothing
end

struct Foo0 end
function Match.extract(::Type{Foo0}, ::Val{2}, p::Foo)
    return (p.x, p.y)
end
struct Foo1 end
function Match.extract(::Type{Foo1}, ::Val{2}, p::Foo)
    return (p.y, p.x)
end
struct Foo2
    x
    y
end
function Match.extract(::Type{Foo2}, ::Val{2}, p::Foo2)
    return (p.y, p.x)
end
struct Foo3
    x
    y
end
function Match.extract(::Type{Foo3}, ::Val{1}, p::Foo3)
    return (p.x,)
end

##########

abstract type RBTree end

struct Leaf <: RBTree
end

struct Red <: RBTree
    value
    left::RBTree
    right::RBTree
end

struct Black <: RBTree
    value
    left::RBTree
    right::RBTree
end

##########

struct Address
    street::AbstractString
    city::AbstractString
    zip::AbstractString
end

struct Person
    firstname::AbstractString
    lastname::AbstractString
    address::Address
end

##########

abstract type Term end

struct Var <: Term
    name::AbstractString
end

struct Fun <: Term
    arg::AbstractString
    body::Term
end

struct App <: Term
    f::Term
    v::Term
end

Base.:(==)(x::Var, y::Var) = x.name == y.name
Base.:(==)(x::Fun, y::Fun) = x.arg == y.arg && x.body == y.body
Base.:(==)(x::App, y::App) = x.f == y.f && x.v == y.v

# Not really the Julian way
function Base.show(io::IO, term::Term)
    @match term begin
        Var(n)    => print(io, n)
        Fun(x, b) => begin
            print(io, "^$x.")
            show(io, b)
        end
        App(f, v) => begin
            print(io, "(")
            show(io, f)
            print(io, " ")
            show(io, v)
            print(io, ")")
        end
    end
end

##########

struct T207a
    x; y; z
    T207a(x, y) = new(x, y, x)
end
Match.match_fieldnames(::Type{T207a}) = (:x, :y)

struct T207b
    x; y; z
    T207b(x, y; z = x) = new(x, y, z)
end

struct T207c
    x; y; z
end
T207c(x, y) = T207c(x, y, x)
Match.match_fieldnames(::Type{T207c}) = (:x, :y)

struct T207d
    x; z; y
    T207d(x, y) = new(x, 23, y)
end
Match.match_fieldnames(::Type{T207d}) = (:x, :y)

struct BoolPair
    a::Bool
    b::Bool
end

#
# Match.jl used to support the undocumented syntax
#
#   @match value pattern
#
# or
#
#   @match(value, pattern)
#
# but this is no longer supported.  The tests herein that used to use
# it now use this macro instead.
#
macro test_match(value, pattern)
    names = unique(collect(Match.getvars(pattern)))
    sort!(names)
    result = (length(names) == 1) ? names[1] : Expr(:tuple, names...)
    esc(Expr(:macrocall, Symbol("@match"), __source__, value, Expr(:call, :(=>), pattern, result)))
end
