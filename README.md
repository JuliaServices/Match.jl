[![Travis Build Status](https://travis-ci.org/kmsquire/Match.jl.svg?branch=master)](https://travis-ci.org/kmsquire/Match.jl)
[![Appveyor Build Status](https://ci.appveyor.com/api/projects/status/2p04pa4wkume806f?svg=true)](https://ci.appveyor.com/project/kmsquire/match-jl)
[![Test Coverage](https://codecov.io/github/kmsquire/Match.jl/coverage.svg?branch=master)](https://codecov.io/github/kmsquire/Match.jl?branch=master)
[![PkgEval.jl Status on Julia 0.5](http://pkg.julialang.org/badges/Match_0.5.svg)](http://pkg.julialang.org/?pkg=Match&ver=0.5)
[![PkgEval.jl Status on Julia 0.6](http://pkg.julialang.org/badges/Match_0.6.svg)](http://pkg.julialang.org/?pkg=Match&ver=0.6)
[![Documentation Status](https://img.shields.io/badge/docs-latest-blue.svg)](https://kmsquire.github.io/Match.jl/latest)

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

See the [documentation](http://kmsquire.github.io/Match.jl/latest/)
for examples of this and other features.

