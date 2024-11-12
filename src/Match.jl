module Match

export @match, MatchFailure, @match_return, @match_fail, @ismatch

using MacroTools: MacroTools, @capture
using Base.Iterators: reverse
using Base: ImmutableDict
using OrderedCollections: OrderedDict

"""
    @match pattern = value
    @match value begin
        pattern1 => result1
        pattern2 => result2
        ...
    end

Match a given value to a pattern or series of patterns.

This macro has two forms.  In the first form

    @match pattern = value

Return the value if it matches the pattern, and bind any pattern variables.
Otherwise, throw `MatchFailure`.

In the second form

    @match value begin
        pattern1 => result1
        pattern2 => result2
        ...
    end

Return `result` for the first matching `pattern`.
If there are no matches, throw `MatchFailure`.

To avoid a `MatchFailure` exception, write the `@match` to handle every possible input.
One way to do that is to add a final case with the wildcard pattern `_`.

# See Also

See also

- `@match_fail`
- `@match_return`
- `@ismatch`

# Patterns:

The following syntactic forms can be used in patterns:

* `_` matches anything
* `x` (an identifier) matches anything, binds value to the variable `x`
* `T(x,y,z)` matches structs of type `T` with fields matching patterns `x,y,z`
* `T(y=1)` matches structs of type `T` whose `y` field equals `1`
* `X(x,y,z)` where `X` is not a type, calls `Match.extract(Val(:X), v)` on the value `v` and matches the result against the tuple pattern `(x,y,z)`
* `[x,y,z]` matches `AbstractArray`s with 3 entries matching `x,y,z`
* `(x,y,z)` matches `Tuple`s with 3 entries matching `x,y,z`
* `[x,y...,z]` matches `AbstractArray`s with at least 2 entries, where `x` matches the first entry, `z` matches the last entry and `y` matches the remaining entries.
* `(x,y...,z)` matches `Tuple`s with at least 2 entries, where `x` matches the first entry, `z` matches the last entry and `y` matches the remaining entries.
* `::T` matches any subtype (`isa`) of type `T`
* `x::T` matches any subtype (`isa`) of T that also matches pattern `x`
* `x || y` matches values which match either pattern `x` or `y` (only variables which exist in both branches will be bound)
* `x && y` matches values which match both patterns `x` and `y`
* `x, if condition end` matches only if `condition` is true (`condition` may use any variables that occur earlier in the pattern eg `(x, y, z where x + y > z)`)
* `x where condition` An alternative form for `x, if condition end`
* Anything else is treated as a constant and tested for equality
* Expressions can be interpolated in as constants via standard interpolation syntax `\$(x)`.  Interpolations may use previously bound variables.

Patterns can be nested arbitrarily.

Repeated variables only match if they are equal (`isequal`). For example `(x,x)` matches `(1,1)` but not `(1,2)`.

# Examples
```julia-repl
julia> value=(1, 2, 3, 4)
(1, 2, 3, 4)

julia> @match (x, y..., z) = value
(1, 2, 3, 4)

julia> x
1

julia> y
(2, 3)

julia> z
4

julia> struct Foo
           x::Int64
           y::String
       end

julia> f(x) = @match x begin
           _::String => :string
           [a,a,a] => (:all_the_same, a)
           [a,bs...,c] => (:at_least_2, a, bs, c)
           Foo(x, "foo") where x > 1 => :foo
       end
f (generic function with 1 method)

julia> f("foo")
:string

julia> f([1,1,1])
(:all_the_same, 1)

julia> f([1,1])
(:at_least_2, 1, Int64[], 1)

julia> f([1,2,3,4])
(:at_least_2, 1, [2, 3], 4)

julia> f([1])
ERROR: MatchFailure([1])
...

julia> f(Foo(2, "foo"))
:foo

julia> f(Foo(0, "foo"))
ERROR: MatchFailure(Foo(0, "foo"))
...

julia> f(Foo(2, "not a foo"))
ERROR: MatchFailure(Foo(2, "not a foo"))
...
```
"""
macro match end

"""
    @match_return value

Inside the result part of a @match case, you can return a given value early.

# Examples
```julia-repl
julia> struct Vect
           x
           y
       end

julia> function norm(v)
           @match v begin
               Vect(x, y) => begin
                   if x==0 && y==0
                       @match_return v
                   end
                   l = sqrt(x^2 + y^2)
                   Vect(x/l, y/l)
                   end
               _ => v
           end
       end
norm (generic function with 1 method)

julia> norm(Vect(2, 3))
Vect(0.5547001962252291, 0.8320502943378437)

julia> norm(Vect(0, 0))
Vect(0, 0)
```
"""
macro match_return end

"""
    @match_fail

Inside the result part of a @match case, you can cause the pattern to fail (as if the pattern did not match).

# Examples
```julia-repl
julia> struct Vect
           x
           y
       end

julia> function norm(v)
           @match v begin
               Vect(x, y) => begin
                   if x==0 && y==0
                       @match_fail
                   end
                   l = sqrt(x^2 + y^2)
                   Vect(x/l, y/l)
                   end
               _ => v
           end
       end
norm (generic function with 1 method)

julia> norm(Vect(2, 3))
Vect(0.5547001962252291, 0.8320502943378437)

julia> norm(Vect(0, 0))
Vect(0, 0)
```
"""
macro match_fail end

"""
    @ismatch value pattern

Return `true` if `value` matches `pattern`, `false` otherwise.  When returning `true`,
binds the pattern variables in the enclosing scope.

See also `@match` for the syntax of patterns

# Examples

```julia-repl
julia> struct Point
            x
            y
        end

julia> p = Point(0, 3)
Point(0, 3)

julia> if @ismatch p Point(0, y)
            println("On the y axis at y = ", y)
        end
On the y axis at y = 3
```

Guarded patterns ought not be used with `@ismatch`, as you can just use `&&` instead:

```julia-repl
julia> if (@ismatch p Point(x, y)) && x < y
            println("The point (", x, ", ", y, ") is in the upper left semiplane")
        end
The point (0, 3) is in the upper left semiplane
```
"""
macro ismatch end

"""
    MatchFailure(value)

Construct an exception to be thrown when a value fails to
match a pattern in the `@match` macro.
"""
struct MatchFailure <: Exception
    value
end

"""
    extract(::Val{x}, value)

Implement extractor with name `x`, returning a tuple of fields of `value`, or nothing if
`x` cannot be extracted from `value`.
"""
extract(::Val, value) = nothing

# const fields only suppored >= Julia 1.8
macro _const(x)
    (VERSION >= v"1.8") ? Expr(:const, esc(x)) : esc(x)
end

is_expr(@nospecialize(e), head::Symbol) = e isa Expr && e.head == head
is_expr(@nospecialize(e), head::Symbol, n::Int) = is_expr(e, head) && length(e.args) == n
is_case(@nospecialize(e)) = is_expr(e, :call, 3) && e.args[1] == :(=>)

include("topological.jl")
include("immutable_vector.jl")
include("bound_pattern.jl")
include("binding.jl")
include("lowering.jl")
include("match_cases_simple.jl")
include("matchmacro.jl")
include("automaton.jl")
include("pretty.jl")
include("match_cases_opt.jl")
include("match_return.jl")

end # module
