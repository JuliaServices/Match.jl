module Match

using Base.Meta

#import Base: subslicedim

export @match, subslicedim

include("matchutils.jl")
include("matchmacro.jl")

end # module
