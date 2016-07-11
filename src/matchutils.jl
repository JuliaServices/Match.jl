### Utilities used by @match macro
# author: Kevin Squire (@kmsquire)

#
# ismatch
#

Base.ismatch{R<:Number}(r::Range{R}, s::Number) = s in r
Base.ismatch{T}(r::Range{T}, s::T) = s in r
Base.ismatch(c::Char, s::Number) = false
Base.ismatch(s::Number, c::Char) = false
Base.ismatch(r,s) = (r == s)

#
# slicedim
#
# "view" version of slicedim

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
    (if (d < 0) | (d > 1);  throw(BoundsError()) end;  view(A, i))

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
# get all symbols in an expression

getvars(e)         = Symbol[]
getvars(e::Symbol) = startswith(string(e),'@') ? Symbol[] : Symbol[e]

function getvars(e::Expr)
    if isexpr(e, :call)
        getvars(e.args[2:end])
    else
        getvars(e.args)
    end
end
getvars(es::AbstractArray) = union([getvars(e) for e in es]...)

#
# getvar
#
# get the symbol from a :(::) expression

getvar(x::Expr) = isexpr(x, :(::)) ? x.args[1] : x
getvar(x::Symbol) = x

#
# check_dim_size_expr
#
# generate an expression to check the size of a variable dimension against an array of expressions

function check_dim_size_expr(val, dim, ex::Expr)
    if length(ex.args) == 0 || !any([isexpr(e, :(...)) for e in ex.args])
        :(Match.checkdims($val, $dim, $(length(ex.args))))
    else
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
    dim <= ndims(val) && size(val, dim) >= dimsize-1
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
               Expr(oper, joinexprs(view(exprs, 1:(len-1)), oper, default), exprs[end])
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
