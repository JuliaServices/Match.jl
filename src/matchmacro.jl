
### Match Expression Info

immutable MatchExprInfo
    tests       ::Vector
    assignments ::Vector
    guards      ::Vector{Expr}
    localsyms   ::Vector{Symbol}
end

MatchExprInfo() = MatchExprInfo(Any[],Any[],Expr[],Symbol[])


## unapply(val, expr, syms, info)
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

function unapply(val, sym::Symbol, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo())

# Symbol defined as a Regex (other Regex cases are handled below)
    if isdefined(current_module(),sym) && 
           isa(eval(current_module(),sym), Regex) &&
           !(sym in syms)
        push!(info.tests, :(ismatch($sym, $val)))

# Symbol in syms
    elseif sym in syms
        push!(info.assignments, (sym, val))

# Constants
    elseif isconst(sym)
        push!(info.tests, :($val == $sym))

    end

    info
end

function unapply(val, expr::Expr, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo())

# Extract guards
    if length(expr.args) == 2 && isexpr(expr.args[2], :if)

        push!(info.guards, expr.args[2].args[1])
        guardsyms = getvars(expr.args[2])
        unapply(val, expr.args[1], union(guardsyms, syms), _eval, info)

# Array/tuple matching
    elseif isexpr(expr, :vcat) || isexpr(expr, :hcat) || isexpr(expr, :hvcat)
        unapply_array(val, expr, syms, _eval, info)

    elseif isexpr(expr, :row)
        # pretend it's :hcat
        unapply_array(val, Expr(:hcat, expr.args...), syms, _eval, info)

    elseif isexpr(expr, :tuple)
        pushnt!(info.tests, _eval(:(isa($val, Tuple))))
        pushnt!(info.tests, _eval(check_tuple_len_expr(val, expr)))

        unapply(val, expr.args, syms, _eval, info)

# Match x::Type
    elseif isexpr(expr, :(::)) && isa(expr.args[1], Symbol) # && isa(eval(current_module(), expr.args[2]), Type)
        typ = expr.args[2]
        sym = expr.args[1]

        if isconst(sym)
            push!(info.tests, :($val == $expr))
        else
            pushnt!(info.tests, _eval(:(isa($val, $typ))))
            if sym in syms
                push!(info.assignments, (expr, val))
            end
        end

        info

# Match a || b (i.e., match either expression)
    elseif isexpr(expr, :(||))
        info1 = unapply(val, expr.args[1], syms, _eval)
        info2 = unapply(val, expr.args[2], syms, _eval)

        ### info.localsyms
        
        # these are used to determine the assignment if the same variable is matched in both a and b
        # they are set to false by default
        g1 = gensym("test1")
        g2 = gensym("test2")

        append!(info.localsyms, info1.localsyms)
        append!(info.localsyms, info2.localsyms)

        if length(info1.assignments) > 0;  push!(info.localsyms, g1);  end
        if length(info2.assignments) > 0;  push!(info.localsyms, g2);  end

        ### info.tests

        # assign g1, g2 during the test, if needed
        expr1 = joinexprs(info1.tests, :&&, :true)
        expr2 = joinexprs(info2.tests, :&&, :true)
        if length(info1.assignments) > 0;  expr1 = :($(esc(g1)) = $expr1);  end
        if length(info2.assignments) > 0;  expr2 = :($(esc(g2)) = $expr2);  end

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

        for (expr, var) in info1.assignments
            vs = getvar(x)
            if !(vs in sharedvars)
                # here and below, we assign to nothing
                # so the type info is removed
                # TODO: move it to $val???
                push!(info.assignments, (vs, :($g1 ? $val : nothing)))
            end
        end

        for (expr, var) in info2.assignments
            vs = getvar(x)
            if !(vs in sharedvars)
                push!(info.assignments, (expr, :($g2 ? $val : nothing)))
            end
        end

        ### info.guards

        # TODO: disallow guards from info1, info2?
        append!(info.guards, info1.guards) 
        append!(info.guards, info2.guards)

        info

# Match calls (or anything resembling a call)
    elseif isexpr(expr, :call)

    # Match Type constructors
        if arg1isa(expr, Type) # isa(eval(current_module(), expr.args[1]), Type)
            typ = eval(current_module(), expr.args[1])
            parms = expr.args[2:end]
            fields = names(typ)
            
            if length(fields) < length(parms)
                error("Too many parameters specified for type $typ")
            end

            if (length(parms) == 0 || !isexpr(parms[end], :(...))) && length(fields) > length(parms)
                error("Not matching against all parameters of $typ")
            end

            pushnt!(info.tests, _eval(:(isa($val, $typ))))
            dotvars = Expr[:($val.($(Expr(:quote, var)))) for var in fields]

            unapply(dotvars, parms, syms, _eval, info)

    # Match Regex "calls"
        elseif arg1isa(expr, Regex)
            m = gensym("m")
            re = expr.args[1]
            parms = expr.args[2:end]

            push!(info.tests, :($m = match($re, $val); $m != nothing))
            # TODO: test number of captures against length of parms?

            if length(parms) > 0
                unapply(:($m.captures), parms, syms, _eval, info)
            else
                info
            end
        else
    # Other calls: evaluate the expression and test for equality
            # TODO: test me!
            push!(info.tests, :($val == $expr))
            info
        end

# Regex strings (r"[a-z]*")
    elseif isexpr(expr, :macrocall) && expr.args[1] == symbol("@r_str")
        append!(info.tests, [_eval(:(isa($val, String))), :(ismatch($expr, $val))])
        info

# Other expressions: evaluate the expression and test for equality...
    else
        # TODO: test me!
        push!(info.tests, :($val == $expr))
        info
    end
end

# Match symbols or complex type fields (e.g., foo.bar) representing a tuples

function unapply(val::Union(Symbol, Expr), exprs::AbstractArray, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo())
    # if isa(val, Expr) && !isexpr(val, :(.))
    #     error("unapply: Array expressions must be assigned to symbols or fields of a complex type (e.g., bar.foo)")
    # end
    
    for i = 1:length(exprs)
        if isexpr(exprs[i], :(...))
            if i < length(exprs) || ndims(exprs) > 1
                error("elipses (...) are only allowed in the last position of an Array/Tuple pattern match.")
            end
            sym = to_array_type(exprs[end].args[1])
            unapply(_eval(:($val[$i:end])), sym, syms, _eval, info)
        else
            unapply(_eval(:($val[$i])), exprs[i], syms, _eval, info)
        end
    end

    info
end


# Match arrays against arrays

function unapply(vs::AbstractArray, es::AbstractArray, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo())
    if length(es) == 1 && isexpr(es[1], :(...))
        sym = to_array_type(es[1].args[1])
        unapply([vs...], sym, syms, _eval, info)

    elseif length(es) == length(vs) == 1
        unapply(vs[1], es[1], syms, _eval, info)

    elseif length(es) == length(vs) == 0
        info

    else
        unapply(vs[1], es[1], syms, _eval, info)
        unapply(sub(vs,2:length(vs)), sub(es,2:length(es)), syms, _eval, info)
    end
end

unapply(vals::Tuple, exprs::Tuple, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo()) = unapply([vals...], [exprs...], syms, _eval, info)

# fallback
function unapply(val, expr, _, _eval::Function, info::MatchExprInfo=MatchExprInfo())
    push!(info.tests, :($val == $expr))
    info
end


# Match symbols or complex type fields (e.g., foo.bar) representing arrays

function unapply_array(val, expr::Expr, syms, _eval::Function, info::MatchExprInfo=MatchExprInfo())

    if isexpr(expr, :vcat)
        dim = 1
    elseif isexpr(expr, :hcat)
        dim = 2
    else
        return unapply(val, expr, syms, _eval, info)
    end

    pushnt!(info.tests, _eval(:(isa($val, AbstractArray))))
    pushnt!(info.tests, _eval(check_dim_size_expr(val, dim, expr)))

    exprs = expr.args

    if (isempty(getvars(exprs)))
        # this array is all constant, so just see if it matches
        push!(info.tests, :(all($val .== $expr)))
    else
        for i = 1:length(exprs)
            if isexpr(exprs[i], :(...))
                if i < length(exprs) || ndims(exprs) > 1
                    error("elipses (...) are only allowed in the last position of an Array pattern match.")
                end
                sym = to_array_type(exprs[end].args[1])
                unapply(_eval(:(Match.subslicedim($val, $dim + max(ndims($val)-2,0), $i:size($val,$dim+max(ndims($val)-2,0))))), 
                        sym, syms, _eval, info)
            else
                s = _eval(:(Match.subslicedim($val, $dim + max(ndims($val)-2,0), $i)))
                unapply(s, exprs[i], syms, _eval, info)
            end
        end
    end

    info
end


function gen_match_expr(val, e, code, use_let::Bool=true)

    valsyms = getvars(val)

    if isempty(valsyms)
        _eval = x->:($(eval(x)))
    else
        _eval = identity
    end

# pattern => val
    if isexpr(e, :(=>))
        (pattern, value) = e.args
        syms = getvars(value)
        info = unapply(val, pattern, syms, _eval)

        # Create let statement for guards, and add it to tests
        if length(info.guards) > 0
            guard_expr = joinexprs(info.guards, :&&)

            guardsyms = getvars(guard_expr)
            guard_assignments = filter(a->(getvar(a[1]) in guardsyms), 
                                       info.assignments)
            guard_assignment_exprs = Expr[:($expr = $val) for (expr, val) in guard_assignments]

            guard_tests = let_expr(guard_expr, guard_assignment_exprs)

            pushnt!(info.tests, guard_tests)
        end
                                      
        # filter and escape regular let assignments
        assignments = filter(assn->(sym = assn[1]; 
                                    isa(sym, Symbol) && sym in syms ||
                                    isexpr(sym, :(::)) && sym.args[1] in syms),
                             info.assignments)

        if use_let
            # Wrap value statement in let
            let_assignments = Expr[:($expr = $val) for (expr, val) in assignments]
            expr = let_expr(value, let_assignments)
        else
            esc_assignments = Expr[Expr(:(=), getvar(expr), _eval(val)) for (expr, val) in assignments]
            expr = Expr(:block, esc_assignments..., value)
        end

        # Wrap expr in test expressions
        if length(info.tests) == 0
            # no tests, exactly one match
            expr
        else
            tests = joinexprs(info.tests, :&&)

            # Returned Expression
            expr = :(if $tests
                         $expr
                     else
                         $code
                     end)

            localsyms = [:($x::Bool = false) for x in info.localsyms]

            let_expr(expr, localsyms)
        end
    elseif isexpr(e, :line)
        Expr(:block, e, code)
        #code
    elseif isa(e, Bool)
        e
    else
        vars = setdiff(getvars(e), [:_])
        if length(vars) > 0
            gen_match_expr(val, Expr(:(=>), e, Expr(:tuple, vars...)), code, false)
        else
            gen_match_expr(val, Expr(:(=>), e, :true), code, false)
        end
    end
end        

# The macro!
macro match(v, m)
    code = :nothing

    if isexpr(m, :block)
        for e in reverse(m.args)
            code = gen_match_expr(v, e, code)
        end
    else
        code = gen_match_expr(v, m, code)
    end

    esc(code)
end

# Function producing/showing the generated code
function fmatch(v, m)
    code = :nothing

    if isexpr(m, :block)
        for e in reverse(m.args)
            code = gen_match_expr(v, e, code)
        end
    else
        code = gen_match_expr(v, m, code)
    end

    code
end
