.. image:: https://travis-ci.org/kmsquire/Match.jl.svg?branch=master
   :target: https://travis-ci.org/kmsquire/Match.jl
   :alt: Travis Build Status
.. image:: https://ci.appveyor.com/api/projects/status/2p04pa4wkume806f?svg=true
   :target: https://ci.appveyor.com/project/kmsquire/match-jl
   :alt: Appveyor Build Status
.. image:: https://codecov.io/github/kmsquire/Match.jl/coverage.svg?branch=master
   :target: https://codecov.io/github/kmsquire/Match.jl?branch=master
   :alt: Test Coverage
.. image:: http://pkg.julialang.org/badges/Match_0.5.svg
   :target: http://pkg.julialang.org/?pkg=Match&ver=0.5
   :alt: PkgEval.jl Status on Julia 0.5
.. image:: http://pkg.julialang.org/badges/Match_0.6.svg
   :target: http://pkg.julialang.org/?pkg=Match&ver=0.6
   :alt: PkgEval.jl Status on Julia 0.6
.. image:: https://readthedocs.org/projects/matchjl/badge/?version=latest
   :target: http://matchjl.readthedocs.io/en/latest/?badge=latest
   :alt: Documentation Status

# Advanced Pattern Matching for Julia

Features:

* Matching against almost any data type with a first-match policy
* Deep matching within data types and matrices
* Variable binding within matches

For alternatives to `Match`, check out the following modules

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

See the [documentation at ReadTheDocs](https://matchjl.readthedocs.org/en/latest/)
for examples of this and other features.

