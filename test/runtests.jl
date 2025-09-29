module Rematch2Tests

using Match
using Match: topological_sort, @__match__
using Test
using Random
using MacroTools: MacroTools

include("testtypes.jl")
include("rematch.jl")
include("rematch2.jl")
include("coverage.jl")
include("nontrivial.jl")
include("topological.jl")
include("match_return.jl")
include("test_ismatch.jl")
include("matchtests.jl")

end # module
