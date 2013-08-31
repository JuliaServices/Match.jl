# Advanced Pattern Matching for Julia

Scala has some of the most advanced pattern matching machinery.  This
package is an attempt to mimic those capabilities in Julia.  Features
include:

* Matching against almost any data type with a first-match policy
* Deep matching within data types and matrices
* Variable binding within matches

For alternatives to `Match`, check out the following modules

* [`PatternDispatch.jl`](https://github.com/toivoh/PatternDispatch.jl) for a more Julia-like function dispatch on patterns.

* [`Match.jl`](https://github.com/zachallaun/Match.jl) which is a similar, but (at this writing) less complete module for pattern matching.

  Note that `Match.jl` is also not listed as an available package for Julia.


## Installation
Use the Julia package manager.  Within Julia, do:
```julia
Pkg.add("Match")
```

## Usage

The package provides one macro, `@match`, which can be used as:

    using Match

    @match item begin
        pattern1              => result1
        pattern2, if cond end => result2
        pattern3 || pattern4  => result3
        _                     => default_result
    end

It is possible to supply variables inside pattern, which will be bound
to corresponding values.  This and other features are best seen with
examples.

### Match types

Julia already does a great job of this with functions and multiple
dispatch, and it is generally be better to use those mechanisms when
possible.  But it can be done here.

```julia
julia> using Match

julia> matchtype(item) = @match item begin
           n::Int               => println("Integers are awesome!")
           str::String          => println("Strings are the best")
           m::Dict{Int, String} => println("Ints for Strings?")
           d::Dict              => println("A Dict! Looking up a word?")
           _                    => println("Something unexpected")
       end
# methods for generic function matchtype
matchtype(item) at none:1

julia> matchtype(66)
Integers are awesome!

julia> matchtype("abc")
Strings are the best

julia> matchtype((Int=>String)[1=>"a",2=>"b"])
Ints for Strings?

julia> matchtype(Dict())
A Dict! Looking up a word?

julia> matchtype(2.0)
Something unexpected
```

### Deep Matching of Composite Types

One nice feature is the ability to match embedded types, as well as
bind variables to components of those types.

```julia
julia> type Address
           street::String
           city::String
           zip::String
       end

julia> type Person
           firstname::String
           lastname::String
           address::Address
       end

julia> personinfo(person) = @match person begin
           Person("Julia", lastname,  _)                             => println("Found Julia $lastname")
           Person(firstname, "Julia", _)                             => println("$firstname Julia was here!")
           Person(firstname, lastname ,Address(_, "Cambridge", zip)) => println("$firstname $lastname lives in zip $zip")
           Person(_...)                                              => println("Unknown person!")
       end

julia> personinfo(Person("Julia", "Robinson", Address("450 Serra Mall", "Stanford", "94305")))
Found Julia Robinson

julia> personinfo(Person("Gaston", "Julia",   Address("1 rue Victor Cousin", "Paris", "75005")))
Gaston Julia was here!

julia> personinfo(Person("Edwin", "Aldrin",   Address("350 Memorial Dr", "Cambridge", "02139")))
Edwin Aldrin lives in zip 02139

julia> personinfo(Person("Linus", "Pauling",  Address("1200 E California Blvd", "Pasadena", "91125")))
Unknown person!
```

### Alternatives and Guards

Alternatives allow a match against one of multiple patterns.

Guards allow a conditional match.  They are not a standard part of
Julia yet, so to get the parser to accept them requires that they
are preceded by a comma and ends with "end".

```julia
julia> function parse_arg(arg::String, value::Any=nothing)
          @match (arg, value) begin
             ("-l",              lang),   if lang != nothing end => println("Language set to $lang")
             ("-o" || "--optim", n::Int),      if 0 < n <= 5 end => println("Optimization level set to $n")
             ("-o" || "--optim", n::Int)                         => println("Illegal optimization level $(n)!")
             ("-h" || "--help",  nothing)                        => println("Help!")
             bad                                                 => println("Unknown argument: $bad")
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

### Regular Expressions

Julia has regular expressions already, of course.  Match builds
on them by allowing binding, by treating patterns like functions.

```julia
julia> function regex_test(str, a=199)
           @match str begin
              Ipv4Addr(string(a), _, octet3, _)                        => "$a._.$octet3._ address found"
              Ipv4Addr(_, _, octet3, _),       if int(octet3) > 30 end => "IPv4 address with octet 3 > 30"
              Ipv4Addr()                                               => "IPv4 address"
       
              EmailAddr(_,domain), if endswith(domain, "ucla.edu") end => "UCLA email address"
              EmailAddr                                                => "Some email address"
       
              r"MCM.*"                                                 => "In the twentieth century..."
           end
       end

julia> regex_test("199.27.77.133")
"199._.77._ address found"

julia> regex_test("128.97.27.37")
"IPv4 address"

julia> regex_test("128.97.27.37",128)
"128._.27._ address found"

julia> regex_test("96.17.70.24")
"IPv4 address with octet 3 > 30"

julia> regex_test("beej@cs.ucla.edu")
"UCLA email address"

julia> regex_test("beej@uchicago.edu")
"Some email address"

julia> regex_test("MCMLXXII")
"In the twentieth century..."

julia> regex_test("Open the pod bay doors, HAL.")
"No match"
```


### Deep Matching Against Arrays

`Arrays` are intrinsic to Julia.  Match allows deep matching
against arrays.

The following examples also demonstrate how Match can be used
strictly for its extraction/binding capabilities, by only matching
against one pattern.

#### Extract first element, rest of vector

```julia
julia> (x,y) = @match([1:4], [a,b...] => (a,b));

julia> x
1

julia> y
3-element Array{Int64,1}:
 2
 3
 4
```

#### Match values at the beginning of a vector

```julia
julia> @match([1:10], [1,2,a...] => a);
```

#### Match and collect columns

```julia
julia> (x,y) = @match([1 2 3; 4 5 6], [a b...] => (a,b));

julia> x
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 1
 4

julia> y
2x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 2 3
 5 6

julia> (x,y,z) = @match([1 2 3; 4 5 6], [a b c] => (a,b,c));

julia> x
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 1
 4

julia> y
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 2
 5

julia> z
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 3
 6

julia> (x,y) = @match([1 2 3; 4 5 6], [[1,4] a b] => (a,b));

julia> x
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 2
 5

julia> y
2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:
 3
 6
```

#### Match and collect rows

```julia
julia> (x,y) = @match([1 2 3; 4 5 6], [a, b] => (a,b));

julia> x
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 1 2 3

julia> y
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4 5 6

julia> (x,y) = @match([1 2 3; 4 5 6; 7 8 9], [a, b...] => (a,b));

julia> x
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 1 2 3

julia> y
2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4 5 6
 7 8 9

julia> @match([1 2 3; 4 5 6], [[1 2 3], a]         =>  a)
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6

julia> @match([1 2 3; 4 5 6], [1 2 3; a]           =>  a)
1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6

julia> @match([1 2 3; 4 5 6; 7 8 9], [1 2 3; a...] =>  a)
2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 4  5  6
 7  8  9
```

#### Match invidual positions

```julia
julia> (x,y,z) = @match([1 2; 3 4], [1 a; b c] => (a,b,c));

julia> x
2

julia> y
3

julia> z
4

julia> (x,y) = @match([1 2; 3 4], [1 a; b...] => (a,b));

julia> x
2

julia> y
1x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:
 3 4
```

#### Match 3D arrays

```julia
julia> a = reshape([1:8], (2,2,2))
2x2x2 Array{Int64,3}:
[:, :, 1] =
 1 3
 2 4

[:, :, 2] =
 5 7
 6 8

julia> (x,y) = @match(a, [b c] => (b,c));

julia> x
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 1 3
 2 4

julia> y
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 5 7
 6 8

julia> (w,x,y,z) = @match(a, [[1 c; b d] e] => (b,c,d,e));

julia> w
2

julia> x
3

julia> y
4

julia> z
2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:
 5 7
 6 8
```

### Notes/Gotchas

There are a few useful things to be aware of when using Match.

* Guards need a comma and an `end`:

    ```julia
    ## Bad::
    julia> _iseven(a) = @match a begin
              n::Int if n%2 == 0 end => println("$n is even")
              m::Int                  => println("$m is odd")
           end
    ERROR: syntax: extra token "if" after end of expression

    julia> _iseven(a) = @match a begin
              n::Int, if n%2 == 0 => println("$n is even")
              m::Int              => println("$m is odd")
           end
    ERROR: syntax: invalid identifier name =>

    ## Good::
    julia> _iseven(a) = @match a begin
              n::Int, if n%2 == 0 end => println("$n is even")
              m::Int                  => println("$m is odd")
           end
    # methods for generic function _iseven
    _iseven(a) at none:1
    ```

* Without a default match, the result is `nothing`:

    ```julia
    julia> test(a) = @match a begin
               n::Int           => "Integer"
               m::FloatingPoint => "Float"
           end

    julia> test("Julia is great")

    julia>
    ```

* In Scala, `_` is a wildcard pattern which matches anything, and is
  not bound as a variable.  

  In `Match` for Julia, `_` has no special meaning.  It can be
  used as a wildcard, and will be bound to the last use if it is
  referenced in the result expression:

    ```julia
    julia> test(a) = @match a begin
               n::Int           => "Integer"
               _::FloatingPoint => "$_ is a Float"
               (_,_)            => "$_ is the second part of a tuple"
           end

    julia> test(1.0)
    "1.0 is a Float"

    julia> test((1,2))
    "2 is the second part of a tuple"
    ```

  Note that variables not referenced in the result expression will not
  be bound (e.g., ``n`` is never bound above).

* If you want to see the code generated for a macro, you can use
  `Match.fmatch`, passing in quoted expressions:

    ```julia
    julia> Match.fmatch(:a, :(begin
               n::Int           => "Integer"
               m::FloatingPoint => "Float"
           end))
    quote  # none, line 2:
        if isa(a,Int) # line 377:
            "Integer"
        else  # /home/kmsquire/.julia/v0.2/Match/src/matchmacro.jl, line 379:
            begin  # line 3:
                if isa(a,FloatingPoint) # line 377:
                    "Float"
                else  # /home/kmsquire/.julia/v0.2/Match/src/matchmacro.jl, line 379:
                    nothing
                end
            end
        end
    end
    ```

