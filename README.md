[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaServices.github.io/Match.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaServices.github.io/Match.jl/dev/)
[![Build Status](https://github.com/JuliaServices/Match.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaServices/Match.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaServices/Match.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaServices/Match.jl)

# Advanced Pattern Matching for Julia

Features:

* Matching against almost any data type with a first-match policy
* Deep matching within data types and matrices
* Variable binding within matches

For alternatives to `Match`, check out

* toivoh's [`PatternDispatch.jl`](https://github.com/toivoh/PatternDispatch.jl) for a more Julia-like function dispatch on patterns.


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
to corresponding values. 

See the [documentation](https://JuliaServices.github.io/Match.jl/stable/)
for examples of this and other features.

