
abstract type Expression end
struct Add <: Expression
    x::Expression
    y::Expression
end
struct Sub <: Expression
    x::Expression
    y::Expression
end
struct Neg <: Expression
    x::Expression
end
struct Mul <: Expression
    x::Expression
    y::Expression
end
struct Div <: Expression
    x::Expression
    y::Expression
end
struct Const <: Expression
    value::Float64
end
struct Variable <: Expression
    name::Symbol
end

macro simplify_top(n, mac)
    top_name = Symbol("simplify_top", n)
    simp_name = Symbol("simplify", n)
    mac1 = copy(mac)
    mac2 = copy(mac)
    push!(mac1.args, quote
        # identity elements
        Add(Const(0.0), x) => x
        Add(x, Const(0.0)) => x
        Sub(x, Const(0.0)) => x
        Mul(Const(1.0), x) => x
        Mul(x, Const(1.0)) => x
        Div(x, Const(1.0)) => x
        Mul(Const(0.0) && x, _) => x
        Mul(_, x && Const(0.0)) => x
        Mul(Const(-0.0) && x, _) => x
        Mul(_, x && Const(-0.0)) => x
        # constant folding
        Add(Const(x), Const(y)) => Const(x + y)
        Sub(Const(x), Const(y)) => Const(x - y)
        Neg(Const(x))           => Const(-x)
        Mul(Const(x), Const(y)) => Const(x * y)
        Div(Const(x), Const(y)) => Const(x / y)
        # Algebraic Identities
        Sub(x, x)               => Const(0.0)
        Neg(Neg(x))             => x
        Sub(x, Neg(y))          => $top_name(Add(x, y))
        Add(x, Neg(y))          => $top_name(Sub(x, y))
        Add(Neg(x), y)          => $top_name(Sub(y, x))
        Neg(Sub(x, y))          => $top_name(Sub(y, x))
        Add(x, x)               => $top_name(Mul(x, Const(2.0)))
        Add(x, Mul(Const(k), x))=> $top_name(Mul(x, Const(k + 1)))
        Add(Mul(Const(k), x), x)=> $top_name(Mul(x, Const(k + 1)))
        # Move constants to the left
        Add(x, k::Const)        => $top_name(Add(k, x))
        Mul(x, k::Const)        => $top_name(Mul(k, x))
        # Move negations up the tree
        Sub(Const(0.0), x)      => Neg(x)
        Sub(Const(-0.0), x)     => Neg(x)
        Sub(Neg(x), y)          => $top_name(Neg($top_name(Add(x, y))))
        Mul(Neg(x), y)          => $top_name(Neg($top_name(Mul(x, y))))
        Mul(x, Neg(y))          => $top_name(Neg($top_name(Mul(x, y))))
        x                       => x
    end)
    push!(mac2.args, quote
        Add(x, y) => $top_name(Add($simp_name(x), $simp_name(y)))
        Sub(x, y) => $top_name(Sub($simp_name(x), $simp_name(y)))
        Mul(x, y) => $top_name(Mul($simp_name(x), $simp_name(y)))
        Div(x, y) => $top_name(Div($simp_name(x), $simp_name(y)))
        Neg(x)    => $top_name(Neg($simp_name(x)))
        x         => x
    end)
    esc(quote
        function $top_name(expr::Expression)
            $mac1
        end
        function $simp_name(expr::Expression)
            $mac2
        end
    end)
end

# @simplify_top(0, Match.@match(expr))
# @simplify_top(1, Rematch.@match(expr))
@simplify_top(2, Match.@__match__(expr))
@simplify_top(3, Match.@match(expr))

@testset "Check some complex cases" begin

    x = Variable(:x)
    y = Variable(:y)
    z = Variable(:z)
    zero = Const(0.0)
    one = Const(1.0)

    e1 = Add(zero, x)
    e2 = Add(x, zero)
    e3 = Sub(x, zero)
    e4 = Mul(one, y)
    e5 = Mul(y, one)
    e6 = Div(z, one)
    e7 = Add(Const(3), Const(4))
    e8 = Sub(Const(5), Const(6))
    e9 = Neg(e7)
    e10 = Mul(e8, e9)
    e11 = Div(e10, Add(one, one))
    e12 = Neg(Neg(e1))
    e13 = Sub(e2, Neg(e3))
    e14 = Add(e4, Neg(e5))
    e15 = Add(Neg(e6), e7)
    e16 = Neg(Sub(e8, e9))
    e17 = Sub(Neg(e10), e11)
    e18 = Add(Neg(e12), Neg(e13))
    e19 = Mul(Neg(e14), e15)
    e20 = Mul(e16, Neg(e17))
    e21 = Sub(Neg(e18), e19)
    e22 = Add(e20, Neg(e21))
    expr = e22

    # The expected results of simplification
    expected = Sub(Const(-63.0), Mul(Const(3.0), x))

    @testset "Check some simple cases" begin
        @test simplify_top2(Sub(x, Neg(y))) == Add(x, y)
        @test simplify_top3(Sub(x, Neg(y))) == Add(x, y)
        @test simplify_top2(Add(x, Neg(y))) == Sub(x, y)
        @test simplify_top3(Add(x, Neg(y))) == Sub(x, y)
    end

    # dump(expr)
    # dump(simplify0(expr))

    # @test simplify0(expr) == expected
    # @test simplify1(expr) == expected
    @test simplify2(expr) == expected
    @test simplify3(expr) == expected

    # function performance_test(expr::Expression)
    #     # GC.gc()
    #     # println("===================== Match.@match")
    #     # @time for i in 1:2000000
    #     #     simplify0(expr)
    #     # end
    #     GC.gc()
    #     println("===================== Rematch.@match")
    #     @time for i in 1:2000000
    #         simplify1(expr)
    #     end
    #     GC.gc()
    #     println("===================== Match.@__match__")
    #     @time for i in 1:2000000
    #         simplify2(expr)
    #     end
    #     GC.gc()
    #     println("===================== Match.@match")
    #     @time for i in 1:2000000
    #         simplify3(expr)
    #     end
    #     GC.gc()
    # end

    # performance_test(expr)
end

@testset "examples from Match.jl" begin
    # matching expressions, example from Match.jl documentation and VideoIO.jl
    # Code has been adapted due to https://github.com/JuliaServices/Match.jl/issues/32
    let
        extract_name(x::Any) = Symbol(string(x))
        extract_name(x::Symbol) = x
        extract_name(e::Expr) = @match e begin
            Expr(:type,      [[_, name], _...])  => name
            Expr(:typealias, [[name, _], _...])  => name
            Expr(:call,      [name, _...])       => name
            Expr(:function,  [sig, _...])        => extract_name(sig)
            Expr(:const,     [assn, _...])       => extract_name(assn)
            Expr(:(=),       [fn, body, _...])   => extract_name(fn)
            Expr(expr_type,  _)                  => error("Can't extract name from ",
                                                            expr_type, " expression:\n",
                                                            "    $e\n")
        end

        @test extract_name(Expr(:type, [true, :name])) == :name
        @test extract_name(Expr(:typealias, [:name, true])) == :name
        @test extract_name(:(name(x))) == :name
        @test extract_name(:(function name(x); end)) == :name
        @test extract_name(:(const name = 12)) == :name
        @test extract_name(:(name = 12)) == :name
        @test extract_name(:(name(x) = x)) == :name
    end
end
