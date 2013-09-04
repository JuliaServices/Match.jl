module Match

using Base.Meta

export @match, @ismatch

include("matchutils.jl")
include("matchmacro.jl")

end # module
