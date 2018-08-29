module Match

using Base.Meta

export @match, @ismatch

include("matchutils.jl")
include("matchmacro.jl")

## Uncomment for debugging
# export unapply, unapply_array, gen_match_expr, subslicedim, getvars, getvar, arg1isa, joinexprs, let_expr, array_type_of, isexpr

end # module
