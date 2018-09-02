using Test
using Match

include("testtypes.jl")

import Base: show

# Type matching
test1(item) = @match item begin
    n::Int                       => "Integers are awesome!"
    str::AbstractString          => "Strings are the best"
    m::Dict{Int,AbstractString}  => "Ints for Strings?"
    d::Dict                      => "A Dict! Looking up a word?"
    _                            => "Something unexpected"
end

d = Dict{Int,AbstractString}(1 => "a", 2 => "b")

@test test1(66)     == "Integers are awesome!"
@test test1("abc")  == "Strings are the best"
@test test1(d)      == "Ints for Strings?"
@test test1(Dict()) == "A Dict! Looking up a word?"
@test test1(2.0)    == "Something unexpected"


# Pattern extraction
# inspired by http://thecodegeneral.wordpress.com/2012/03/25/switch-statements-on-steroids-scala-pattern-matching/

# struct Address
#     street::AbstractString
#     city::AbstractString
#     zip::AbstractString
# end

# struct Person
#     firstname::AbstractString
#     lastname::AbstractString
#     address::Address
# end

test2(person) = @match person begin
    Person("Julia", lastname,  _) => "Found Julia $lastname"
    Person(firstname, "Julia", _) => "$firstname Julia was here!"
    Person(firstname, lastname, Address(_, "Cambridge", zip)) => "$firstname $lastname lives in zip $zip"
    _::Person  => "Unknown person!"
end

@test test2(Person("Julia", "Robinson", Address("450 Serra Mall", "Stanford", "94305")))         == "Found Julia Robinson"
@test test2(Person("Gaston", "Julia",   Address("1 rue Victor Cousin", "Paris", "75005")))       == "Gaston Julia was here!"
@test test2(Person("Edwin", "Aldrin",   Address("350 Memorial Dr", "Cambridge", "02139")))       == "Edwin Aldrin lives in zip 02139"
@test test2(Person("Linus", "Pauling",  Address("1200 E California Blvd", "Pasadena", "91125"))) == "Unknown person!"  # Really?


# Guards, pattern extraction
# translated from Scala Case-classes http://docs.scala-lang.org/tutorials/tour/case-classes.html

##
## Untyped lambda calculus definitions
##

# abstract type Term end

# struct Var <: Term
#     name::AbstractString
# end

# struct Fun <: Term
#     arg::AbstractString
#     body::Term
# end

# struct App <: Term
#     f::Term
#     v::Term
# end

# scala defines these automatically...
import Base.==

==(x::Var, y::Var) = x.name == y.name
==(x::Fun, y::Fun) = x.arg == y.arg && x.body == y.body
==(x::App, y::App) = x.f == y.f && x.v == y.v


# Not really the Julian way
function show(io::IO, term::Term)
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

# Guard test is here
function is_identity_fun(term::Term)
    @match term begin
        Fun(x, Var(y)), if x == y end => true
        _ => false
    end
end


id = Fun("x", Var("x"))
t = Fun("x", Fun("y", App(Var("x"), Var("y"))))

let io = IOBuffer()
    show(io, id)
    @test String(take!(io)) == "^x.x"
    show(io, t)
    @test String(take!(io)) == "^x.^y.(x y)"
    @test is_identity_fun(id)
    @test !is_identity_fun(t)
end

# Test single terms

myisodd(x::Int) = @match(x, i => i % 2 == 1)
@test filter(myisodd, 1:10) == filter(isodd, 1:10) == [1, 3, 5, 7, 9]

# Alternatives, Guards

function parse_arg(arg::AbstractString, value::Any=nothing)
    @match (arg, value) begin
        ("-l",              lang),   if lang != nothing end => "Language set to $lang"
        ("-o" || "--optim", n::Int),      if 0 < n <= 5 end => "Optimization level set to $n"
        ("-o" || "--optim", n::Int)                         => "Illegal optimization level $(n)!"
        ("-h" || "--help",  nothing)                        => "Help!"
        bad                                                 => "Unknown argument: $bad"
    end
end

@test parse_arg("-l", "eng")  == "Language set to eng"
@test parse_arg("-l")         == "Unknown argument: (\"-l\", nothing)"
@test parse_arg("-o", 4)      == "Optimization level set to 4"
@test parse_arg("--optim", 5) == "Optimization level set to 5"
@test parse_arg("-o", 0)      == "Illegal optimization level 0!"
@test parse_arg("-o", 1.0)    == "Unknown argument: (\"-o\", 1.0)"

@test parse_arg("-h") == parse_arg("--help") == "Help!"


# Regular Expressions

# TODO: Fix me!

# Note: the following test only works because Ipv4Addr and EmailAddr
# are (module-level) globals!

# const Ipv4Addr = r"(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})"
# const EmailAddr = r"\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+\.[A-Z]{2,4})\b"i

# function regex_test(str)
#     ## Defining these in the function doesn't work, because the macro
#     ## (and related functions) don't have access to the local
#     ## variables.

#     # Ipv4Addr = r"(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})"
#     # EmailAddr = r"\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+\.[A-Z]{2,4})\b"i

#     @match str begin
#         Ipv4Addr(_, _, octet3, _),       if int(octet3) > 30 end => "IPv4 address with octet 3 > 30"
#         Ipv4Addr()                                               => "IPv4 address"

#         EmailAddr(_,domain), if endswith(domain, "ucla.edu") end => "UCLA email address"
#         EmailAddr                                                => "Some email address"

#         r"MCM.*"                                                 => "In the twentieth century..."

#         _                                                        => "No match"
#     end
# end

# @test regex_test("128.97.27.37")                 == "IPv4 address"
# @test regex_test("96.17.70.24")                  == "IPv4 address with octet 3 > 30"

# @test regex_test("beej@cs.ucla.edu")             == "UCLA email address"
# @test regex_test("beej@uchicago.edu")            == "Some email address"

# @test regex_test("MCMLXXII")                     == "In the twentieth century..."
# @test regex_test("Open the pod bay doors, HAL.") == "No match"


# Pattern extraction from arrays

# extract first, rest from array
# (b is a subarray of the original array)
@test @match([1:4;], [a, b...])                             == (1, [2, 3, 4])
@test @match([1:4;], [a..., b])                             == ([1, 2, 3], 4)
@test @match([1:4;], [a, b..., c])                           == (1, [2, 3], 4)

# match particular values at the beginning of a vector
@test @match([1:10;], [1, 2, a...])                          == [3:10;]
@test @match([1:10;], [1, a..., 9, 10])                       == [2:8;]

# match / collect columns
@test @match([1 2 3; 4 5 6], [a b...])                    == ([1, 4], [2 3; 5 6])
@test @match([1 2 3; 4 5 6], [a... b])                    == ([1 2; 4 5], [3, 6])
@test @match([1 2 3; 4 5 6], [a b c])                     == ([1, 4], [2, 5], [3, 6])
@test @match([1 2 3; 4 5 6], [[1, 4] a b])                 == ([2, 5], [3, 6])

@test @match([1 2 3 4; 5 6 7 8], [a b... c])              == ([1, 5], [2 3; 6 7], [4, 8])


# match / collect rows
@test @match([1 2 3; 4 5 6], [a, b])                      == ([1, 2, 3], [4, 5, 6])
@test @match([1 2 3; 4 5 6], [[1, 2, 3], a])                ==  [4, 5, 6]             # TODO: don't match this
#@test @match([1 2 3; 4 5 6], [1 2 3; a])                  ==  [4,5,6]

@test @match([1 2 3; 4 5 6; 7 8 9], [a, b...])            == ([1, 2, 3], [4 5 6; 7 8 9])
@test @match([1 2 3; 4 5 6; 7 8 9], [a..., b])            == ([1 2 3; 4 5 6], [7, 8, 9])
#@test @match([1 2 3; 4 5 6; 7 8 9], [1 2 3; a...])        ==  [4 5 6; 7 8 9]

#@test @match([1 2 3; 4 5 6; 7 8 9; 10 11 12], [a,b...,c]) == ([1,2,3], [4 5 6; 7 8 9], [10 11 12])

# match invidual positions
#@test @match([1 2; 3 4], [1 a; b c])                      == (2,3,4)
#@test @match([1 2; 3 4], [1 a; b...])                     == (2,[3,4])

# @test @match([ 1  2  3  4
#                  5  6  7  8
#                  9 10 11 12
#                 13 14 15 16
#                 17 18 19 20 ],
#
#                 [1      a...
#                  b...
#                  c... 15 16
#                  d 18 19 20])                               == ([2,3,4], [5 6 7 8; 9 10 11 12], [13,14], 17)




# match 3D arrays
m = reshape([1:8;], (2, 2, 2))
@test @match(m, [a b])                                    == ([1 3; 2 4], [5 7; 6 8])

# match against an expression
function get_args(ex::Expr)
    @match ex begin
        Expr(:call, [:+, args...]) => args
        _ => "None"
    end
end

@test get_args(Expr(:call, :+, :x, 1)) == [:x, 1]

# Zach Allaun's fizzbuzz (https://github.com/zachallaun/Match.jl#awesome-fizzbuzz)

function fizzbuzz(range::AbstractRange)
    io = IOBuffer()
    for n in range
        @match (n % 3, n % 5) begin
            (0, 0) => print(io, "fizzbuzz ")
            (0, _) => print(io, "fizz ")
            (_, 0) => print(io, "buzz ")
            (_, _) => print(io, n, ' ')
        end
    end
    String(take!(io))
end

@test fizzbuzz(1:15) == "1 2 fizz 4 buzz fizz 7 8 fizz buzz 11 fizz 13 14 fizzbuzz "

# Zach Allaun's "Balancing Red-Black Trees" (https://github.com/zachallaun/Match.jl#balancing-red-black-trees)

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

function balance(tree::RBTree)
    @match tree begin
        (Black(z, Red(y, Red(x, a, b), c), d)
         || Black(z, Red(x, a, Red(y, b, c)), d)
         || Black(x, a, Red(z, Red(y, b, c), d))
         || Black(x, a, Red(y, b, Red(z, c, d)))) => Red(y, Black(x, a, b),
                                                         Black(z, c, d))
        tree => tree
    end
end

@test balance(Black(1, Red(2, Red(3, Leaf(), Leaf()), Leaf()), Leaf())) ==
            Red(2, Black(3, Leaf(), Leaf()),
                Black(1, Leaf(), Leaf()))


function num_match(n)
    @match n begin
        0      => "zero"
        1 || 2 => "one or two"
        3:10   => "three to ten"
        _      => "something else"
    end
end

@test num_match(0) == "zero"
@test num_match(2) == "one or two"
@test num_match(4) == "three to ten"
@test num_match(12) == "something else"
@test num_match("hi") == "something else"
@test num_match('c') == "something else"

function char_match(c)
    @match c begin
        'A':'Z' => "uppercase"
        'a':'z' => "lowercase"
        '0':'9' => "number"
        _       => "other"
    end
end

@test char_match('M') == "uppercase"
@test char_match('n') == "lowercase"
@test char_match('8') == "number"
@test char_match(' ') == "other"
@test char_match("8") == "other"
@test char_match(8) == "other"

# Interpolation of matches in quoted expressions
test_interp(item) = @match item begin
    [a, b] => :($a + $b)
end
@test test_interp([1, 2]) == :(1 + 2)
