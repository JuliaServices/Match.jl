module Match

using Base.Meta

export @match, @ismatch

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
    deleteat! = splice!
end


include("matchutils.jl")
include("matchmacro.jl")

end # module
