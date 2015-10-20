using Compat

use_fieldnames = VERSION >= v"0.4.0-dev+3609"

### Match Expression Info

immutable MatchExprInfo
    tests             ::Vector{Expr}
    guard_assignments ::Vector{NTuple}
    assignments       ::Vector{NTuple}
    guards            ::Vector{Expr}
    test_assign       ::Vector{NTuple}
end

MatchExprInfo() = MatchExprInfo(Expr[],NTuple[],NTuple[],Expr[],NTuple[])

## unapply(val, expr, syms, guardsyms, valsyms, info)
##
## Generate code which matches val with expr,
## decomposing val or expr as needed.
##
## * Constant values are tested for equality.
##
## * Regex values are tested using ismatch() or
##   match() when there are variables to extract
##
## * Variables assignments are created for symbols
##   in expr which exist in syms
##
## * More complex expressions are handled specially
##   (e.g., a || b allows matching against a or b)

function unapply(val, sym::Symbol, syms, guardsyms, valsyms, info, array_checked::Bool=false)

# # Symbol defined as a Regex (other Regex cases are handled below)
#     if isdefined(current_module(),sym) &&
#            isa(eval(current_module(),sym), Regex) &&
#            !(sym in guardsyms) && !(sym in valsyms)
#         push!(info.tests, :(Match.ismatch($sym, $val)))

# Symbol in syms
    if sym in syms
        (sym in guardsyms) && push!(info.guard_assignments, (sym, val))
        (sym in valsyms)   && push!(info.assignments, (sym, val))

# Constants
    else
        push!(info.tests, :(Match.ismatch($sym,$val)))
    end

    info
end

function unapply(val, expr::Expr, syms, guardsyms, valsyms, info, array_checked::Bool=false)

# Match calls (or anything resembling a call)
    if isexpr(expr, :call)

        # Match Type constructors
        if length(syms) == 0
            push!(info.tests, :(Match.ismatch($expr, $val)))
            info
        else
            # Assume this is a type
            typ = expr.args[1]
            parms = expr.args[2:end]

            push!(info.tests, :(isa($val, $typ)))
            # TODO: this verifies the that the number of fields is correct.
            #       We might want to force an error (e.g., by using an assert) instead.
            if use_fieldnames
                push!(info.tests, :(length(fieldnames($typ)) == $(length(expr.args)-1)))
            else
                push!(info.tests, :(length(names($typ)) == $(length(expr.args)-1)))
            end

            dotnums = Expr[:($val.($i)) for i in 1:length(expr.args)-1]

            unapply(dotnums, parms, syms, guardsyms, valsyms, info, array_checked)
        end

# Tuple matching
    elseif isexpr(expr, :tuple)
        if isexpr(val, :tuple)
            check_tuple_len(val, expr)
            unapply(val.args, expr.args, syms, guardsyms, valsyms, info, array_checked)
        else
            push!(info.tests, :(isa($val, Tuple)))
            push!(info.tests, check_tuple_len_expr(val, expr))
            unapply(val, expr.args, syms, guardsyms, valsyms, info, array_checked)
        end

        info

    elseif isexpr(expr, :vcat) | isexpr(expr, :hcat) | isexpr(expr, :hvcat) | isexpr(expr, :cell1d) | isexpr(expr, :vect)
        unapply_array(val, expr, syms, guardsyms, valsyms, info)

    elseif isexpr(expr, :row)
        # pretend it's :hcat
        unapply_array(val, Expr(:hcat, expr.args...), syms, guardsyms, valsyms, info)

# Match a || b (i.e., match either expression)
    elseif isexpr(expr, :(||))
        info1 = unapply(val, expr.args[1], syms, guardsyms, valsyms, MatchExprInfo(), array_checked)
        info2 = unapply(val, expr.args[2], syms, guardsyms, valsyms, MatchExprInfo(), array_checked)

        ### info.test_assign

        # these are used to determine the assignment if the same variable is matched in both a and b
        # they are set to false by default
        g1 = gensym("test1")
        g2 = gensym("test2")

        append!(info.test_assign, info1.test_assign)
        append!(info.test_assign, info2.test_assign)

        if length(info1.assignments) > 0;  push!(info.test_assign, (g1, false));  end
        if length(info2.assignments) > 0;  push!(info.test_assign, (g2, false));  end

        ### info.tests

        # assign g1, g2 during the test, if needed
        expr1 = joinexprs(unique(info1.tests), :&&, :true)
        expr2 = joinexprs(unique(info2.tests), :&&, :true)
        if length(info1.assignments) > 0;  expr1 = :($g1 = $expr1);  end
        if length(info2.assignments) > 0;  expr2 = :($g2 = $expr2);  end

        push!(info.tests, Expr(:(||), expr1, expr2))

        ### info.assignments

        # fix up let assignments to determine which variables to match
        vars1 = [getvar(x) => (x,y) for (x,y) in info1.assignments]
        vars2 = [getvar(x) => (x,y) for (x,y) in info2.assignments]

        sharedvars = intersect(keys(vars1), keys(vars2))

        for var in sharedvars
            (expr1, val1) = vars1[var]
            (expr2, val2) = vars2[var]

            # choose most specific variable typing
            if expr1 == expr2 || !isexpr(expr2, :(::))
                expr = expr1
            elseif !isexpr(expr1, :(::))
                expr = expr2
            else
                # here, both vars are typed, but with different types
                # let the parser figure out the best typing
                expr = var
            end

            push!(info.assignments, (expr, :($g1 ? $val1 : $val2)))
        end

        for (expr, val) in info1.assignments
            vs = getvar(expr)
            if !(vs in sharedvars)
                # here and below, we assign to nothing
                # so the type info is removed
                # TODO: move it to $val???
                push!(info.assignments, (expr, :($g1 ? $val : nothing)))
            end
        end

        for (expr, val) in info2.assignments
            vs = getvar(expr)
            if !(vs in sharedvars)
                push!(info.assignments, (expr, :($g2 ? $val : nothing)))
            end
        end

        ### info.guards

        # TODO: disallow guards from info1, info2?
        append!(info.guards, info1.guards)
        append!(info.guards, info2.guards)

        info

# Match x::Type
    elseif isexpr(expr, :(::)) && isa(expr.args[1], Symbol)
        typ = expr.args[2]
        sym = expr.args[1]

        push!(info.tests, :(isa($val, $typ)))
        if sym in syms
            sym in guardsyms && push!(info.guard_assignments, (expr, val))
            sym in valsyms   && push!(info.assignments, (expr, val))
        end

        info

# Regex strings (r"[a-z]*")
    elseif isexpr(expr, :macrocall) && expr.args[1] == symbol("@r_str")
        append!(info.tests, [:(isa($val, String)), :(Match.ismatch($expr, $val))])
        info

# Other expressions: evaluate the expression and test for equality...
    else
        # TODO: test me!
        push!(info.tests, :(Match.ismatch($expr, $val)))
        info
    end
end

# Match symbols or complex type fields (e.g., foo.bar) representing a tuples

function unapply(val::Union{Symbol, Expr}, exprs::AbstractArray, syms, guardsyms, valsyms,
                 info, array_checked::Bool=false)
    # if isa(val, Expr) && !isexpr(val, :(.))
    #     error("unapply: Array expressions must be assigned to symbols or fields of a complex type (e.g., bar.foo)")
    # end

    seen_dots = false
    for i = 1:length(exprs)
        if isexpr(exprs[i], :(...))
            if seen_dots #i < length(exprs) || ndims(exprs) > 1
                error("elipses (...) are only allowed once in an Array/Tuple pattern match.") #in the last position of
            end
            seen_dots = true
            sym = array_type_of(exprs[i].args[1])
            unapply(:($val[$i:(end-$(length(exprs)-i))]), sym, syms, guardsyms, valsyms, info, array_checked)
        elseif seen_dots
            unapply(:($val[end-$(length(exprs)-i)]), exprs[i], syms, guardsyms, valsyms, info, array_checked)
        else
            unapply(:($val[$i]), exprs[i], syms, guardsyms, valsyms, info, array_checked)
        end
    end

    info
end


# Match arrays against arrays

function unapply(vs::AbstractArray, es::AbstractArray, syms, guardsyms, valsyms,
                 info, array_checked::Bool=false)
    if isexpr(es[1], :(...))
        sym = array_type_of(es[1].args[1])
        unapply(vs[1:end-(length(es)-1)], sym, syms, guardsyms, valsyms, info, array_checked)

    elseif length(es) == length(vs) == 1
        unapply(vs[1], es[1], syms, guardsyms, valsyms, info, array_checked)

    elseif length(es) == length(vs) == 0
        info

    else
        unapply(vs[1], es[1], syms, guardsyms, valsyms, info, array_checked)
        unapply(sub(vs,2:length(vs)), sub(es,2:length(es)), syms, guardsyms, valsyms, info, array_checked)
    end
end

unapply(vals::Tuple, exprs::Tuple, syms, guardsyms, valsyms,
        info, array_checked::Bool=false) =
    unapply([vals...], [exprs...], syms, guardsyms, valsyms, info, array_checked)

# fallback
function unapply(val, expr, _1, _2, _3,
                 info, array_checked::Bool=false)
    push!(info.tests, :(Match.ismatch($expr, $val)))
    info
end


# Match symbols or complex type fields (e.g., foo.bar) representing arrays

function unapply_array(val, expr::Expr, syms, guardsyms, valsyms, info, array_checked::Bool=false)

    if isexpr(expr, :vcat) || isexpr(expr, :cell1d) || isexpr(expr, :vect)
        dim = 1
    elseif isexpr(expr, :hcat) # || isexpr(expr, :hvcat)
        # TODO: check hvcat...
        dim = 2
    else
        error("unapply_array() called on a non-array expression")
    end

    sdim = :($dim+max(ndims($val)-2,0))

    if !array_checked #!(isexpr(val, :call) && val.args[1] == :(Match.subslicedim))
        # if we recursively called this with subslicedim (below),
        # don't do these checks
        # TODO: if there are nested arrays in the match, these checks
        #       should actually be done!
        # TODO: need to make this test more robust if we're only doing it once...

        #push!(info.tests, :(isa($val, AbstractArray)))
        #push!(info.tests, check_dim_size_expr(val, sdim, expr))
        push!(info.tests, check_dim_size_expr(val, dim, expr))
        array_checked=true
    end

    exprs = expr.args
    seen_dots = false
    if (isempty(getvars(exprs)))
        # this array is all constant, so just see if it matches
        push!(info.tests, :(all($val .== $expr)))
    else
        for i = 1:length(exprs)
            if isexpr(exprs[i], :(...))
                if seen_dots # i < length(exprs) || ndims(exprs) > 1
                    error("elipses (...) are only allowed once in an an Array pattern match.") #in the last position of
                end
                seen_dots = true
                sym = array_type_of(exprs[i].args[1])
                j = length(exprs)-i
                s = :(Match.slicedim($val, $dim, $i, $j))
                unapply(s, sym, syms, guardsyms, valsyms, info, array_checked)
            elseif seen_dots
                j = length(exprs)-i
                s = :(Match.slicedim($val, $dim, $j, true))
                unapply(s, exprs[i], syms, guardsyms, valsyms, info, array_checked)
            else
                s = :(Match.slicedim($val, $dim, $i))
                unapply(s, exprs[i], syms, guardsyms, valsyms, info, array_checked)
            end
        end

    end

    info
end


function gen_match_expr(v, e, code, use_let::Bool=true)

# pattern => val
    if isexpr(e, :(=>))
        info = MatchExprInfo()

        (pattern, value) = e.args

        # Extract guards
        if isexpr(pattern, :tuple) && length(pattern.args) == 2 && isexpr(pattern.args[2], :if)
            guard = pattern.args[2].args[1]
            pattern = pattern.args[1]
            push!(info.guards, guard)
            guardsyms = getvars(guard)
        else
            guardsyms = Symbol[]
        end

        syms = getvars(pattern)
        valsyms = getvars(value)

        info = unapply(v, pattern, syms, guardsyms, valsyms, info)

        # Create let statement for guards, and add it to tests
        if length(info.guards) > 0
            guard_expr = joinexprs(info.guards, :&&)

            guard_assignment_exprs = Expr[:($expr = $val) for (expr, val) in info.guard_assignments]

            guard_tests = let_expr(guard_expr, guard_assignment_exprs)

            push!(info.tests, guard_tests)
        end

        # filter and escape regular let assignments
        # assignments = filter(assn->(sym = assn[1];
        #                             isa(sym, Symbol) && sym in syms ||
        #                             isexpr(sym, :(::)) && sym.args[1] in syms),
        #                      info.assignments)
        assignments = info.assignments

        if use_let
            # Wrap value statement in let
            let_assignments = Expr[:($expr = $val) for (expr, val) in assignments]
            expr = let_expr(value, let_assignments)
        else
            esc_assignments = Expr[Expr(:(=), getvar(expr), val) for (expr, val) in assignments]
            expr = Expr(:block, esc_assignments..., value)
        end

        # Wrap expr in test expressions
        if length(info.tests) == 0
            # no tests, exactly one match
            expr
        else
            tests = joinexprs(info.tests, :&&)

            # Returned Expression
            if expr == :true && code == :false
                expr = tests
            else
                expr = :(if $tests
                             $expr
                         else
                             $code
                         end)
            end

            test_assign = [:($expr = $val) for (expr,val) in info.test_assign]

            let_expr(expr, test_assign)
        end
    elseif isexpr(e, :line) || isa(e, LineNumberNode)
        Expr(:block, e, code)
        #code
    elseif isa(e, Bool)
        e
    else
        error("@match patterns must consist of :(=>) blocks")
    end
end

# The match macro
macro match(v, m)
    code = :nothing

    if isexpr(m, :block)
        for e in reverse(m.args)
            code = gen_match_expr(v, e, code)
        end
    elseif isexpr(m, :(=>))
        code = gen_match_expr(v, m, code)
    else
        code = :(error("Pattern does not match"))
        vars = setdiff(getvars(m), [:_]) |> syms -> filter(x->!@compat(startswith(string(x),"@")), syms)
        if length(vars) == 0
            code = gen_match_expr(v, Expr(:(=>), m, :true), code, false)
        elseif length(vars) == 1
            code = gen_match_expr(v, Expr(:(=>), m, vars[1]), code, false)
        else
            code = gen_match_expr(v, Expr(:(=>), m, Expr(:tuple, vars...)), code, false)
        end
    end

    esc(code)
end

# Function producing/showing the generated code
fmatch(v, m) = macroexpand(:(@match $v $m))

# The ismatch macro
macro ismatch(val, m)
    code = gen_match_expr(val, Expr(:(=>), m, :true), :false)
    esc(code)
end


fismatch(val, m) = macroexpand(:(@ismatch $val $m))

