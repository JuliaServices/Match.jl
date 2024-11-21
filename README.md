[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaServices.github.io/Match.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaServices.github.io/Match.jl/dev/)
[![Build Status](https://github.com/JuliaServices/Match.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaServices/Match.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaServices/Match.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaServices/Match.jl)

# Advanced Pattern Matching for Julia

Features:

* Matching against almost any data type with a first-match policy
* Deep matching within data types, tuples, and vectors
* Variable binding within matches
* Produces a decision automaton to avoid repeated tests between patterns.

## Installation
Use the Julia package manager.  Within Julia, do:
```julia
Pkg.add("Match")
```

## Usage

The package provides two macros for pattern-matching: `@match` and `@ismatch`.
It is possible to supply variables inside patterns, which will be bound
to corresponding values.

    using Match

    @match item begin
        pattern1              => result1
        pattern2, if cond end => result2
        pattern3 || pattern4  => result3
        _                     => default_result
    end

    if @ismatch value pattern
        # Code that uses variables bound in the pattern
    end

See the [documentation](https://JuliaServices.github.io/Match.jl/stable/)
for examples of this and other features.

## Patterns

* `_` matches any value
* `x` (an identifier) matches any value and binds it to the variable `x`
* `1` (a literal value) matches that value
* `T(x,y,z)` matches structs of type `T` with fields matching patterns `x,y,z`
* `T(y=p)` matches structs of type `T` whose `y` field matches pattern `p`
* `(;x,y,z)` matches values with fields `x,y,z` binding to variables `x,y,z`
* `(;x=p)` matches values with field `x` matching pattern `p`; also binds the field to `x`
* `(;x::T)` matches values with field `x` matching pattern `::T`; also binds the field to `x`
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
* `if condition end` A boolean computed pattern. `x && if condition end` is another way of writing `x where condition`.
* Anything else is treated as a constant and tested for equality
* Expressions can be interpolated in as constants via standard interpolation syntax `$(x)`.  Interpolations may use previously bound variables.

Patterns can be nested arbitrarily.

Repeated variables only match if they are equal (`isequal`). For example `(x,x)` matches `(1,1)` but not `(1,2)`.

## Early exit and failure

Inside the result part of a case, you can cause the pattern to fail (as if the pattern did not match), or you can return a value early:

```julia
@match value begin
    pattern1 => begin
        if some_failure_condition
            @match_fail
        end
        if some_shortcut_condition
            @match_return 1
        end
        ...
        2
    end
    ...
end
```

In this example, the result value when matching `pattern1` is a block that has two early exit conditions.
When `pattern1` matches but `some_failure_condition` is `true`, then the whole case is treated as not matching and the following cases are tried.
Otherwise, if `some_shortcut_condition` is `true`, then `1` is the result value for this case.
Otherwise `2` is the result.

## Differences from previous versions of `Match.jl`

* If no branches are matched, throws `MatchFailure` instead of returning nothing.
* Matching against a struct with the wrong number of fields produces an error instead of silently failing.
* Repeated variables require equality, ie `@match (1,2) begin (x,x) => :ok end` fails.
* We add a syntax for guards `x where x > 1` in addition to the existing `x, if x > 1 end`.
* Structs can be matched by field-names, allowing partial matches: `@match Foo(1,2) begin Foo(y=2) => :ok end` returns `:ok`.
* Patterns support interpolation, ie `let x=1; @match ($x,$(x+1)) = (1,2); end` is a match.
* We have dropped support for matching against multidimensional arrays - all array patterns use linear indexing.
* We no longer support the (undocumented) syntax `@match value pattern` which returned an array of the bindings of the pattern variables.
* Errors now identify a specific line in the user's program where the problem occurred.
* Previously bound variables may now be used in interpolations, ie `@match (x, $(x+2)) = (1, 3)` is a match.
* A pure type match (without another pattern) can be written as `::Type`.
* Types appearing in type patterns (`::Type`) and struct patterns (`Type(...)`) are bound at macro-expansion time in the context of the module containing the macro usage.  As a consequence, you cannot use certain type expressions that would differ.  For example, you cannot use a type parameter or a local variable containing a type.  The generated code checks that the type is the same at evaluation time as it was at macro expansion time, and an error is thrown if they differ.  If this rare incompatibility affects you, you can use `x where x isa Type` as a workaround.  If the type is not defined at macro-expansion time, an error is issued.
* A warning is issued at macro-expansion time if a case cannot be reached because it is subsumed by prior cases.
* Versions prior to `2.0.0` treated unexpected expressions as interpolations. For example, a pattern of the form `a.b` would be evaluated at pattern-match time and compared to the input. Interpolations now require the `$` syntax: `$(a.b)`.
