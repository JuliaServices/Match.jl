# Match.jl --- Advanced Pattern Matching for Julia

This package provides both simple and advanced pattern matching capabilities for Julia. Features include:

- Matching against almost any data type with a first-match policy
- Deep matching within data types and matrices
- Variable binding within matches

# Installation

Use the Julia package manager. Within Julia, do:

```julia
Pkg.add("Match")
```

# Usage

The package provides one macro, @match, which can be used as:

```julia
using Match

@match item begin
    pattern1              => result1
    pattern2, if cond end => result2
    pattern3 || pattern4  => result3
    _                     => default_result
end
```

Patterns can be values, regular expressions, type checks or constructors, tuples, or arrays, including multidimensional arrays. It is possible to supply variables inside pattern, which will be bound to corresponding values. This and other features are best seen with examples.

## Match Values

The easiest kind of matching to use is simply to match against values:

```julia
@match item begin
   1 => "one"
   2 => "two"
   _ => "Something else..."
end
```

## Match Types

Julia already does a great job of this with functions and multiple dispatch, and it is generally be better to use those mechanisms when possible. But it can be done here:

```julia
julia> matchtype(item) = @match item begin
           n::Int               => println("Integers are awesome!")
           str::String          => println("Strings are the best")
           m::Dict{Int, String} => println("Ints for Strings?")
           d::Dict              => println("A Dict! Looking up a word?")
           _                    => println("Something unexpected")
   end

julia> matchtype(66)
Integers are awesome!

julia> matchtype("abc")
Strings are the best

julia> matchtype(Dict{Int, String}(1=>"a",2=>"b"))
Ints for Strings?

julia> matchtype(Dict())
A Dict! Looking up a word?

julia> matchtype(2.0)
Something unexpected
```

## Deep Matching of Composite Types

One nice feature is the ability to match embedded types, as well as bind variables to components of those types:

```julia
struct Address
    street::String
    city::String
    zip::String
end

struct Person
    firstname::String
    lastname::String
    address::Address
end

personinfo(person) = @match person begin
  Person("Julia", lname,  _)           => "Found Julia $lname"
  Person(fname, "Julia", _)            => "$fname Julia was here!"
  Person(fname, lname,
         Address(_, "Cambridge", zip)) => "$fname $lname lives in zip $zip"
  Person(_...)                         => "Unknown person!"
end

julia> personinfo(Person("Julia", "Robinson",
                  Address("450 Serra Mall", "Stanford", "94305")))
"Found Julia Robinson"

julia> personinfo(Person("Gaston", "Julia",
                  Address("1 rue Victor Cousin", "Paris", "75005")))
"Gaston Julia was here!"

julia> personinfo(Person("Edwin", "Aldrin",
                  Address("350 Memorial Dr", "Cambridge", "02139")))
"Edwin Aldrin lives in zip 02139"

julia> personinfo(Person("Linus", "Pauling",
                  Address("1200 E California Blvd", "Pasadena", "91125")))
"Unknown person!"
```

## Alternatives and Guards

Alternatives allow a match against multiple patterns.

Guards allow a conditional match. They are not a standard part of Julia yet, so to get the parser to accept them requires that they are preceded by a comma and end with "end":

```julia
function parse_arg(arg::String, value::Any=nothing)
  @match (arg, value) begin
    ("-l",              lang)    => println("Language set to $lang")
    ("-o" || "--optim", n::Int),
     if 0 < n <= 5 end           => println("Optimization level set to $n")
    ("-o" || "--optim", n::Int)  => println("Illegal optimization level $(n)!")
    ("-h" || "--help",  nothing) => println("Help!")
    bad                          => println("Unknown argument: $bad")
  end
end

julia> parse_arg("-l", "eng")
Language set to eng

julia> parse_arg("-l")
Unknown argument: ("-l",nothing)

julia> parse_arg("-o", 4)
Optimization level set to 4

julia> parse_arg("--optim", 5)
Optimization level set to 5

julia> parse_arg("-o", 0)
Illegal optimization level 0!

julia> parse_arg("-o", 1.0)
Unknown argument: ("-o",1.0)

julia> parse_arg("-h")
Help!

julia> parse_arg("--help")
Help!
```

## Match Ranges

Borrowing a nice idea from pattern matching in Rust, pattern matching against ranges is also supported:

```julia
julia> function num_match(n)
           @match n begin
               0      => "zero"
               1 || 2 => "one or two"
               3:10   => "three to ten"
               _      => "something else"
           end
       end
num_match (generic function with 1 method)

julia> num_match(0)
"zero"

julia> num_match(2)
"one or two"

julia> num_match(12)
"something else"

julia> num_match('c')
"something else"
```

Note that a range can still match another range exactly:

```julia
julia> num_match(3:10)
"three to ten"
```

## Regular Expressions

Match.jl used to have complex regular expression handling, but it was implemented using `eval`, which is generally a bad idea and was the source of some undesirable behavior.

With some work, it may be possible to reimplement, but it's unclear if this is a good idea yet.

## Deep Matching Against Arrays

Arrays are intrinsic components of Julia. Match allows deep matching against arrays.

The following examples also demonstrate how Match can be used strictly for its extraction/binding capabilities, by only matching against one pattern.

### Extract first element, rest of vector

```julia
julia> @match([1:4], [a,b...]);

julia> a
1

julia> b
3-element SubArray{Int64,1,Array{Int64,1},(Range1{Int64},)}:
 2
 3
 4
```

### Match values at the beginning of a vector

```julia
julia> @match([1:5], [1,2,a...])
 3-element SubArray{Int64,1,Array{Int64,1},(Range1{Int64},)}:
  3
  4
  5
```

### Match and collect columns

```julia
julia> @match([1 2 3; 4 5 6], [a b...]);

julia> a
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 1
 4

julia> b
2x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 2 3
 5 6

julia> @match([1 2 3; 4 5 6], [a b c]);

julia> a
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 1
 4

julia> b
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 2
 5

julia> c
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 3
 6

julia> @match([1 2 3; 4 5 6], [[1,4] a b]);

julia> a
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 2
 5

julia> b
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 3
 6
```

### Match and collect rows

```julia
julia> @match([1 2 3; 4 5 6], [a, b]);

julia> a
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 1 2 3

julia> b
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4 5 6

julia> @match([1 2 3; 4 5 6; 7 8 9], [a, b...]);

julia> a
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 1 2 3

julia> b
2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4 5 6
 7 8 9

julia> @match([1 2 3; 4 5 6], [[1 2 3], a])
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6

julia> @match([1 2 3; 4 5 6], [1 2 3; a])
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6

julia> @match([1 2 3; 4 5 6; 7 8 9], [1 2 3; a...])
2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6
 7  8  9
```

### Match individual positions

```julia
julia> @match([1 2; 3 4], [1 a; b c]);

julia> a
2

julia> b
3

julia> c
4

julia> @match([1 2; 3 4], [1 a; b...]);

julia> a
2

julia> b
1x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 3 4
```

### Match 3D arrays

```julia
julia> m = reshape([1:8], (2,2,2))
2x2x2 Array{Int64,3}:
[:, :, 1] =
 1 3
 2 4

[:, :, 2] =
 5 7
 6 8

julia> @match(m, [a b]);

julia> a
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 1 3
 2 4

julia> b
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 5 7
 6 8

julia> @match(m, [[1 a; b c] d]);

julia> a
3

julia> b
2

julia> c
4

julia> d
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 5 7
 6 8
```

## Notes/Gotchas

There are a few useful things to be aware of when using Match.

- Guards need a comma and an \`end\`:

  ## Bad

        julia> _iseven(a) = @match a begin
                n::Int if n%2 == 0 end => println("$n is even")
                m::Int                 => println("$m is odd")
            end
        ERROR: syntax: extra token "if" after end of expression

        julia> _iseven(a) = @match a begin
                n::Int, if n%2 == 0 => println("$n is even")
                m::Int              => println("$m is odd")
            end
        ERROR: syntax: invalid identifier name =>

  ## Good

        julia> _iseven(a) = @match a begin
                n::Int, if n%2 == 0 end => println("$n is even")
                m::Int                  => println("$m is odd")
            end
        # methods for generic function _iseven
        _iseven(a) at none:1

- Without a default match, the result is \`nothing\`:

        julia> test(a) = @match a begin
                    n::Int           => "Integer"
                    m::FloatingPoint => "Float"
                end

        julia> test("Julia is great")

        julia>

- In Scala, \_ is a wildcard pattern which matches anything, and is not bound as a variable.

  In Match for Julia, \_ can be used as a wildcard, and will be bound to the last use if it is referenced in the result expression:

        julia> test(a) = @match a begin
                    n::Int           => "Integer"
                    _::FloatingPoint => "$_ is a Float"
                    (_,_)            => "$_ is the second part of a tuple"
                end

        julia> test(1.0)
        "1.0 is a Float"

        julia> test((1,2))
        "2 is the second part of a tuple"

- Note that variables not referenced in the result expression will not be bound (e.g., `n` is never bound above). One small exception to this rule is that when "=&gt;" is not used, "\_" will not be assigned.

- If you want to see the code generated for a macro, you can use \`macroexpand\`:

        julia> macroexpand(:(@match(a, begin
                                n::Int           => "Integer"
                                    m::FloatingPoint => "Float"
                                end))
        quote  # REPL[1], line 2:
            if isa(a,Int) # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 387:
                "Integer"
            else  # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 389:
                begin  # REPL[1], line 3:
                    if isa(a,FloatingPoint) # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 387:
                        "Float"
                    else  # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 389:
                        nothing
                    end
                end
            end
        end

# Examples

Here are a couple of additional examples.

## Mathematica-Inspired Sparse Array Constructor

[Contributed by @benkj](https://github.com/kmsquire/Match.jl/issues/29)

> I've realized that `Match.jl` is perfect for creating in Julia an equivalent of [SparseArray](https://reference.wolfram.com/language/ref/SparseArray.html) which I find quite useful in Mathematica.
>
> My basic implementation is this:
>
>     macro sparsearray(size, rule)
>         return quote
>             _A = spzeros($size...)
>             $(push!(rule.args, :(_ => 0)))
>
>             for _itr in eachindex(_A)
>                 _A[_itr] = @match(_itr.I, $rule)
>             end
>             _A
>         end
>     end
>
> Example:
>
>     julia> A = @sparsearray (5,5)  begin
>                    (n,m), if n==m+1 end => m
>                    (n,m), if n==m-1 end => n+10
>                    (1,5) => 1
>            end
>
> which creates the matrix:
>
>     julia> full(A)
>     5x5 Array{Float64,2}:
>      0.0  11.0   0.0   0.0   1.0
>      1.0   0.0  12.0   0.0   0.0
>      0.0   2.0   0.0  13.0   0.0
>      0.0   0.0   3.0   0.0  14.0
>      0.0   0.0   0.0   4.0   0.0

## Matching Exprs

The `@match` macro can be used to match Julia expressions (`Expr` objects). One issue is that the [internal structure of Expr objects](http://docs.julialang.org/en/release-0.4/manual/metaprogramming/#program-representation) doesn't match their constructor exactly, so one has to put arguments in brackets, as well as capture the `typ` field of macros.

The following function is a nice example of matching expressions. It is used in `VideoIO.jl` to extract the names of expressions generated by `Clang.jl`, for later filtering and rewriting.:

```julia
extract_name(x) = string(x)
function extract_name(e::Expr)
    @match e begin
        Expr(:type,      [_, name, _])     => name
        Expr(:typealias, [name, _])        => name
        Expr(:call,      [name, _...])     => name
        Expr(:function,  [sig, _...])      => extract_name(sig)
        Expr(:const,     [assn, _...])     => extract_name(assn)
        Expr(:(=),       [fn, body, _...]) => extract_name(fn)
        Expr(expr_type,  _...)             => error("Can't extract name from ",
                                                     expr_type, " expression:\n",
                                                     "    $e\n")
    end
end
```

# Inspiration

The following pages on pattern matching in scala provided inspiration for the library:

- <http://thecodegeneral.wordpress.com/2012/03/25/switch-statements-on-steroids-scala-pattern-matching/>
- <http://java.dzone.com/articles/scala-pattern-matching-case>
- <http://kerflyn.wordpress.com/2011/02/14/playing-with-scalas-pattern-matching/>
- <http://docs.scala-lang.org/tutorials/tour/case-classes.html>
