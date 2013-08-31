module Match

using Base.Meta

#import Base: subslicedim

export @match, @fmatch, subslicedim

include("matchutils.jl")
include("matchmacro.jl")

end # module
