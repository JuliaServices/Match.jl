module Match

using Base.Meta

export @match, @ismatch, @switch

include("matchutils.jl")
include("matchmacro.jl")

end # module
