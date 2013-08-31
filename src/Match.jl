module Match

using Base.Meta

export @match

include("matchutils.jl")
include("matchmacro.jl")

end # module
