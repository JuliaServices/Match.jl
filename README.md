# Advanced Pattern Matching for Julia

Scala has some of the most advanced pattern matching machinery.  This
package is an attempt to mimic those capabilities in Julia.  Features
include:

* Matching against almost any data type with a first-match policy
* Deep matching within data types and matrices
* Variable binding within matches

For alternatives to `Match`, check out the following modules

* toivoh's [`PatternDispatch.jl`](https://github.com/toivoh/PatternDispatch.jl) for a more Julia-like function dispatch on patterns.

* Zach Allaun's [`Match.jl`](https://github.com/zachallaun/Match.jl) which is a similar, but (at this writing) less complete module for pattern matching.

  Note that Zach's `Match.jl` is also not listed as an available package for Julia.  (Zach kindly offered to let this package use the same name--thanks!)


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

