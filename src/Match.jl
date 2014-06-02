module Match

using Base.Meta

export @match, @ismatch

import Base.ismatch

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
    deleteat! = splice!
end


include("matchutils.jl")
include("matchmacro.jl")

## Uncomment for debugging
# export unapply, unapply_array, gen_match_expr, subslicedim, getvars, getvar, arg1isa, joinexprs, let_expr, array_type_of, isexpr

end # module
