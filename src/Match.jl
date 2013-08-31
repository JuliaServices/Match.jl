module Match

using Base.Meta

#import Base: subslicedim

export @match

include("matchutils.jl")
include("matchmacro.jl")

end # module
