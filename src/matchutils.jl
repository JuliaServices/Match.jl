### Utilities used by @match macro
# author: Kevin Squire (@kmsquire)

using Compat
import ArrayViews.view

#
# Fallback for ismatch
#

ismatch(r,s) = (r == s)

#
# slicedim
#
# "sub" version of slicedim, to get an array slice as a view

function _slicedim(A::AbstractArray, d::Integer, i::Integer)
    if (d < 1) | (d > ndims(A))
        throw(BoundsError())
    end
    sz = size(A)
    # Force 1x..x1 slices to extract the value
    # Note that this is no longer a reference.
    otherdims = [sz...]
    splice!(otherdims, d)
    if all(otherdims .== 1)
        A[[ n==d ? i : 1 for n in 1:ndims(A) ]...]
    else
        view(A, [ n==d ? i : (1:sz[n]) for n in 1:ndims(A) ]...)
    end
end

function _slicedim(A::AbstractArray, d::Integer, i)
    if (d < 1) | (d > ndims(A))
        throw(BoundsError())
    end
    sz = size(A)
    view(A, [ n==d ? i : (1:sz[n]) for n in 1:ndims(A) ]...)
end

_slicedim(A::AbstractVector, d::Integer, i::Integer) =
    (if (d < 0) | (d > 1);  throw(BoundsError()) end;  A[i])

_slicedim(A::AbstractVector, d::Integer, i) =
    (if (d < 0) | (d > 1);  throw(BoundsError()) end;  sub(A, i))

function slicedim(A::AbstractArray, s::Integer, i::Integer, from_end::Bool = false)
    d = s + max(ndims(A)-2, 0)
    from_end && (i = size(A,d)-i)
    _slicedim(A, d, i)
end

function slicedim(A::AbstractArray, s::Integer, i::Integer, j::Integer)
    d = s + max(ndims(A)-2, 0)
    j = size(A,d)-j # this is the distance from the end of the dim size
    _slicedim(A, d, i:j)
end

#
# getvars
#
# get all symbols in an expression (including undefined symbols)

getvars(e,all=false)         = Symbol[]
getvars(e::Symbol,all=false) = @compat startswith(string(e),'@') ? Symbol[] : Symbol[e]

function getvars(e::Expr, all=false)
    if isexpr(e, :call)
        getvars(e.args[2:end], all)
    elseif isexpr(e, :copyast) || isexpr(e, :quote)
        Symbol[]
    else
        getvars(e.args, all)
    end
end
getvars(es::AbstractArray,all=false) = union([getvars(e,all) for e in es]...)

#
# getvar
#
# get the symbol from a :(::) expression

getvar(x::Expr) = isexpr(x, :(::)) ? x.args[1] : x
getvar(x::Symbol) = x

#
# arg1istype
#
# checks if expr.arg[1] is a Type

#arg1isa(e::Expr, typ::Type) = isa(eval(current_module(), e.args[1]), typ)


#
# check_dim_size_expr
#
# generate an expression to check the size of a variable dimension against an array of expressions

function check_dim_size_expr(val, dim, ex::Expr)
    if length(ex.args) == 0 || !any([isexpr(e, :(...)) for e in ex.args])
        #:($dim <= ndims($val) && size($val, $dim) == $(length(ex.args)))
        :(Match.checkdims($val, $dim, $(length(ex.args))))
    else
        #:($dim <= ndims($val) && size($val, $dim) >= $(length(ex.args)-1))
        :(Match.checkdims2($val, $dim, $(length(ex.args))))
    end
end

function checkdims(val::AbstractArray, dim, dimsize)
    dim = dim + max(ndims(val)-2, 0)
    dim <= ndims(val) && size(val, dim) == dimsize
end

checkdims(val, dim, dimsize) = false

function checkdims2(val::AbstractArray, dim, dimsize)
    dim = dim + max(ndims(val)-2, 0)
    dim <= ndims(val) && size(val, dim) >= dimsize
end

checkdims2(val, dim, dimsize) = false


#
# check_tuple_len_expr
#
# generate an expression to check the length of a tuple variable against a tuple expression

function check_tuple_len_expr(val, ex::Expr)
    if length(ex.args) == 0 || !any([isexpr(e, :(...)) for e in ex.args])
        :(length($val) == $(length(ex.args)))
    else
        :(length($val) >= $(length(ex.args)-1))
    end
end

function check_tuple_len(val::Expr, ex::Expr)
    if !isexpr(val, :tuple) || !isexpr(ex, :tuple)
        false
    elseif length(ex.args) == 0 || !any([isexpr(e, :(...)) for e in ex.args])
        length(val.args) == length(ex.args)
    else
        length(val.args) >= length(ex.args)-1
    end
end


#
# joinexprs
#
# join an array of (e.g., true/false) expressions with an operator

function joinexprs(exprs::AbstractArray, oper::Symbol, default=:nothing)
    len = length(exprs)

    len == 0 ? default :
    len == 1 ? exprs[1] :
               Expr(oper, joinexprs(sub(exprs, 1:(len-1)), oper, default), exprs[end])
end


#
# let_expr
#
# generate an optional let expression

let_expr(expr, assignments::AbstractArray) =
    length(assignments) > 0 ? Expr(:let, expr, assignments...) : expr

#
# array_type_of
#
# modify x::Type => x::AbstractArray{Type}

function array_type_of(ex::Expr)
    if isexpr(ex, :(::))
        :($(ex.args[1])::AbstractArray{$(ex.args[2])})
    else
        ex
    end
end

array_type_of(sym::Symbol) = :($sym::AbstractArray)
