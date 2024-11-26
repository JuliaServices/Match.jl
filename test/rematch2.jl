# Note we do not use `@eval` to define types within a `@testset``
# because we need the types to be defined during macro expansion,
# which is earlier than evaluation.  types are looked up during
# expansion of the `@match` macro so we can use the known bindings
# of types to generate more efficient code.

file = Symbol(@__FILE__)

@enum Color Yellow Blue Greed

macro casearm1(pattern, value)
    esc(:($pattern => $value))
end

macro casearm2(pattern, value)
    esc(:(@casearm1 $pattern $value))
end

macro check_is_identifier(x)
    false
end
macro check_is_identifier(x::Symbol)
    true
end

@testset "Yet more @match tests" begin

@testset "test the simplest form of regex matches, which are supported by Match.jl" begin
    function is_ipv4_address(s)
        @match s begin
            r"(\d+)\.(\d+)\.(\d+)\.(\d+)" => true
            _ => false
        end
    end
    @test is_ipv4_address("192.168.0.5")
    @test !is_ipv4_address("www.gafter.com")
end

@testset "identical regex matching" begin
    function func(x)
        @match x begin
            r"abc" => true
            _ => false
        end
    end
    # check that we are backward compatible in allowing a regex to match a regex.
    @test func("abc")
    @test func(r"abc")
    @test !func(:abc)
end

@testset "identical range matching" begin
    function func(x)
        @match x begin
            3:10 => true
            _ => false
        end
    end
    # check that we are backward compatible in allowing a range to match a range.
    @test func(3)
    @test func(10)
    @test func(3:10)
    @test !func(2:9)
end

@testset "Check that `,if condition end` guards are parsed properly 1" begin
    x = true
    @test (@match 3 begin
        ::Int, if x end => 1
        _ => 2
    end) == 1

    x = false
    @test (@match 3 begin
        ::Int, if x end => 1
        _ => 2
    end) == 2
end

@testset "Check that `,if condition end` guards are parsed properly 2" begin
    x = true
    @test (@match 3 begin
        (::Int, if x end) => 1
        _ => 2
    end) == 1

    x = false
    @test (@match 3 begin
        (::Int, if x end) => 1
        _ => 2
    end) == 2
end

@testset "Check that `where` clauses are reparsed properly 1" begin
    x = true
    @test (@match 3 begin
        ::Int where x => 1
        _ => 2
    end) == 1

    x = false
    @test (@match 3 begin
        ::Int where x => 1
        _ => 2
    end) == 2
end

@testset "Check that `where` clauses are reparsed properly 2" begin
    x = true
    @test (@match 3 begin
        a::Int where x => a
        _ => 2
    end) == 3

    x = false
    @test (@match 3 begin
        a::Int where x => a
        _ => 2
    end) == 2
end

@testset "Check that `where` clauses are reparsed properly 3" begin
    let line = 0
        try
            line = (@__LINE__) + 2
            @eval @match Foo(1, 2) begin
                (Foo where unbound)(1, 2) => 1
            end
            @test false
        catch ex
            @test ex isa LoadError
            e = ex.error
            @test e isa ErrorException
            @test e.msg == "$file:$line: Unrecognized pattern syntax `(Foo where unbound)(1, 2)`."
        end
    end
end

@testset "Check that `where` clauses are reparsed properly 4" begin
    for b1 in [false, true]
        for b2 in [false, true]
            @test (@match 3 begin
                ::Int where b1 where b2 => 1
                _ => 2
            end) == ((b1 && b2) ? 1 : 2)
        end
    end
end

@testset "Check that `where` clauses are reparsed properly 5" begin
    for b1 in [false, true]
        for b2 in [false, true]
            @test (@match 3 begin
                ::Int where b1 == b2 => 1
                _ => 2
            end) == ((b1 == b2) ? 1 : 2)
        end
    end
end

@testset "Assignments in the value do not leak out" begin
    @match Foo(1, 2) begin
        Foo(x, 2) => begin
            new_variable = 3
        end
    end
    @test !(@isdefined x)
    @test !(@isdefined new_variable)
end

@testset "Assignments in a where clause do not leak out" begin
    @match Foo(1, 2) begin
        Foo(x, 2) where begin
            new_variable = 3
            true
        end => begin
            @test !(@isdefined new_variable)
        end
    end
    @test !(@isdefined x)
    @test !(@isdefined new_variable)
end

@testset "A pure type pattern" begin
    @test (@match ::Symbol = :test1) == :test1
    @test (@match ::String = "test2") == "test2"
    @test_throws MatchFailure(:test1) @match ::String = :test1
    @test_throws MatchFailure("test2") @match ::Symbol = "test2"
end

@testset "bound variables may be used in subsequent interpolations" begin
    let x = nothing, y = nothing
        @test (@match (x, y, $(x + 2)) = (1, 2, 3)) == (1, 2, 3)
        @test x == 1
        @test y == 2
    end
end

#
# To print the decision automaton shown in comments below, replace @match_count_nodes
# with @match_dump and run the test.  To show the full details of how the decision
# automaton was computed, try @match_dumpall.
#

@testset "test for decision automaton optimizations 1" begin
    # Node 1 TEST «input_value» isa Foo ELSE: Node 5 («label_0»)
    # Node 2 FETCH «input_value.y» := «input_value».y
    # Node 3 TEST «input_value.y» == 2 ELSE: Node 5 («label_0»)
    # Node 4 MATCH 1 with value 1
    # Node 5 («label_0») FAIL (throw)((Match.MatchFailure)(«input_value»))
    @test (Match.@match_count_nodes some_value begin
        Foo(x, 2) => 1
    end) == 5
end

@testset "test for decision automaton optimizations 2" begin
    # Node 1 TEST «input_value» isa Foo ELSE: Node 6 («label_0»)
    # Node 2 FETCH «input_value.y» := «input_value».y
    # Node 3 TEST «input_value.y» == 2 ELSE: Node 5 («label_1»)
    # Node 4 MATCH 1 with value 1
    # Node 5 («label_1») MATCH 2 with value 2
    # Node 6 («label_0») MATCH 3 with value 4
    @test (Match.@match_count_nodes some_value begin
        Foo(x, 2) => 1
        Foo(_, _) => 2
        _ => 4
    end) == 6
end

@testset "test for decision automaton optimizations 3" begin
    # Node 1 TEST «input_value» isa Foo ELSE: Node 7 («label_0»)
    # Node 2 FETCH «input_value.x» := «input_value».x
    # Node 3 FETCH «input_value.y» := «input_value».y
    # Node 4 TEST «input_value.y» == 2 ELSE: Node 6 («label_1»)
    # Node 5 MATCH 1 with value (identity)(«input_value.x»)
    # Node 6 («label_1») MATCH 2 with value 2
    # Node 7 («label_0») FAIL (throw)((Match.MatchFailure)(«input_value»))
    @test (Match.@match_count_nodes some_value begin
        Foo(x, 2) => x
        Foo(_, _) => 2
        _ => 4
    end) == 7
end

@testset "test for decision automaton optimizations 4" begin
    # Node 1 TEST «input_value» isa Foo ELSE: Node 7 («label_0»)
    # Node 2 FETCH «input_value.x» := «input_value».x
    # Node 3 FETCH «input_value.y» := «input_value».y
    # Node 4 TEST «input_value.y» == «input_value.x» ELSE: Node 6 («label_1»)
    # Node 5 MATCH 1 with value (identity)(«input_value.x»)
    # Node 6 («label_1») MATCH 2 with value 2
    # Node 7 («label_0») MATCH 3 with value 4
    @test (Match.@match_count_nodes some_value begin
        Foo(x, x) => x
        Foo(_, _) => 2
        _ => 4
    end) == 7
end

@testset "test for sharing where clause conjuncts" begin
    # Node 1 TEST «input_value» isa Main.Rematch2Tests.Foo ELSE: Node 18 («label_2»)
    # Node 2 FETCH «input_value.x» := «input_value».x
    # Node 3 FETCH «input_value.y» := «input_value».y
    # Node 4 TEST «input_value.y» == 2 ELSE: Node 9 («label_5»)
    # Node 5 FETCH «where_0» := (f1)(«input_value.x»)
    # Node 6 TEST where «where_0» ELSE: Node 8 («label_4»)
    # Node 7 MATCH 1 with value 1
    # Node 8 («label_4») TEST «input_value.x» == 1 THEN: Node 10 ELSE: Node 18 («label_2»)
    # Node 9 («label_5») TEST «input_value.x» == 1 ELSE: Node 13 («label_3»)
    # Node 10 FETCH «where_1» := (f2)(«input_value.y»)
    # Node 11 TEST where «where_1» ELSE: Node 18 («label_2»)
    # Node 12 MATCH 2 with value 2
    # Node 13 («label_3») FETCH «where_0» := (f1)(«input_value.x»)
    # Node 14 TEST where «where_0» ELSE: Node 18 («label_2»)
    # Node 15 FETCH «where_1» := (f2)(«input_value.y»)
    # Node 16 TEST where «where_1» ELSE: Node 18 («label_2»)
    # Node 17 MATCH 3 with value 3
    # Node 18 («label_2») MATCH 4 with value 4
    @test (Match.@match_count_nodes some_value begin
        Foo(x, 2) where f1(x)            => 1
        Foo(1, y) where f2(y)            => 2
        Foo(x, y) where (f1(x) && f2(y)) => 3
        _                                => 4
    end) == 18
end

@testset "test for sharing where clause disjuncts" begin
    # Node 1 TEST «input_value» isa Main.Rematch2Tests.Foo ELSE: Node 18 («label_2»)
    # Node 2 FETCH «input_value.x» := «input_value».x
    # Node 3 FETCH «input_value.y» := «input_value».y
    # Node 4 TEST «input_value.y» == 2 ELSE: Node 11 («label_3»)
    # Node 5 FETCH «where_0» := (f1)((identity)(«input_value.x»))
    # Node 6 TEST !«where_0» ELSE: Node 8 («label_5»)
    # Node 7 MATCH 1 with value 1
    # Node 8 («label_4») TEST «input_value.x» == 1 THEN: Node 10 ELSE: Node 18 («label_2»)
    # Node 9 («label_5») TEST «input_value.x» == 1 ELSE: Node 13 («label_3»)
    # Node 10 FETCH «where_1» := (f2)(«input_value.y»)
    # Node 11 TEST where !«where_1» ELSE: Node 18 («label_2»)
    # Node 12 MATCH 2 with value 2
    # Node 13 («label_3») FETCH «where_0» := (f1)(«input_value.x»)
    # Node 14 TEST where !«where_0» ELSE: Node 18 («label_2»)
    # Node 15 FETCH «where_1» := (f2)(«input_value.y»)
    # Node 16 TEST where !«where_1» ELSE: Node 18 («label_2»)
    # Node 17 MATCH 3 with value 3
    # Node 18 («label_2») MATCH 4 with value 5
    @test (Match.@match_count_nodes some_value begin
        Foo(x, 2) where !f1(x)            => 1
        Foo(1, y) where !f2(y)            => 2
        Foo(x, y) where !(f1(x) || f2(y)) => 3
        _                                 => 5
    end) == 18
end

@testset "exercise the dumping code for coverage" begin
    io = IOBuffer()
    @test (Match.@match_dumpall io some_value begin
        Foo(x, 2) where !f1(x)            => 1
        Foo(1, y) where !f2(y)            => 2
        Foo(x, y) where !(f1(x) || f2(y)) => 3
        _                                 => 5
    end) == 18
    @test (Match.@match_dump io some_value begin
        Foo(x, 2) where !f1(x)            => 1
        Foo(1, y) where !f2(y)            => 2
        Foo(x, y) where !(f1(x) || f2(y)) => 3
        _                                 => 5
    end) == 18
end

@testset "test for correct semantics of complex where clauses" begin
    function f1(a, b, c, d, e, f, g, h)
        @match (a, b, c, d, e, f, g, h) begin
            (a, b, c, d, e, f, g, h) where (!(!((!a || !b) && (c || !d)) || !(!e || f) && (g || h))) => 1
            (a, b, c, d, e, f, g, h) where (!((!a || b) && (c || d) || (e || !f) && (!g || !h))) => 2
            (a, b, c, d, e, f, g, h) where (!((a || b) && !(!c || !d) || !(!(!e || f) && !(g || !h)))) => 3
            (a, b, c, d, e, f, g, h) where (!(!(a || !b) && (!c || !d)) || !(!(e || !f) && (!g || h))) => 4
            (a, b, c, d, e, f, g, h) where (!(a || !b) && (!c || d) || (e || f) && !(!g || h)) => 5
            _ => 6
        end
    end
    function f2(a, b, c, d, e, f, g, h)
        # For reference we use the brute-force implementation of pattern-matching that just
        # performs the tests sequentially, like writing an if-elseif-else chain.
        Match.@__match__ (a, b, c, d, e, f, g, h) begin
            (a, b, c, d, e, f, g, h) where (!(!((!a || !b) && (c || !d)) || !(!e || f) && (g || h))) => 1
            (a, b, c, d, e, f, g, h) where (!((!a || b) && (c || d) || (e || !f) && (!g || !h))) => 2
            (a, b, c, d, e, f, g, h) where (!((a || b) && !(!c || !d) || !(!(!e || f) && !(g || !h)))) => 3
            (a, b, c, d, e, f, g, h) where (!(!(a || !b) && (!c || !d)) || !(!(e || !f) && (!g || h))) => 4
            (a, b, c, d, e, f, g, h) where (!(a || !b) && (!c || d) || (e || f) && !(!g || h)) => 5
            _ => 6
        end
    end
    function f3(a, b, c, d, e, f, g, h)
        @test f1(a, b, c, d, e, f, g, h) == f2(a, b, c, d, e, f, g, h)
    end
    for t in Iterators.product(([false, true] for a in 1:8)...,)
        f3(t...)
    end
end

@testset "infer positional parameters from Match.match_fieldnames(T) 1" begin
    # struct T207a
    #     x; y; z
    #     T207a(x, y) = new(x, y, x)
    # end
    # Match.match_fieldnames(::Type{T207a}) = (:x, :y)
    r = @match T207a(1, 2) begin
        T207a(x, y) => x
    end
    @test r == 1
    r = @match T207a(1, 2) begin
        T207a(x, y) => y
    end
    @test r == 2
end

@testset "infer positional parameters from Match.match_fieldnames(T) 3" begin
    # struct T207c
    #     x; y; z
    # end
    # T207c(x, y) = T207c(x, y, x)
    # Match.match_fieldnames(::Type{T207c}) = (:x, :y)
    r = @match T207c(1, 2) begin
        T207c(x, y) => x
    end
    @test r == 1
    r = @match T207c(1, 2) begin
        T207c(x, y) => y
    end
    @test r == 2
end

@testset "infer positional parameters from Match.match_fieldnames(T) 4" begin
    # struct T207d
    #     x; z; y
    #     T207d(x, y) = new(x, 23, y)
    # end
    # Match.match_fieldnames(::Type{T207d}) = (:x, :y)
    r = @match T207d(1, 2) begin
        T207d(x, y) => x
    end
    @test r == 1
    r = @match T207d(1, 2) begin
        T207d(x, y) => y
    end
    @test r == 2
end

@testset "diagnostics produced are excellent" begin

    @testset "infer positional parameters from Match.match_fieldnames(T) 2" begin
        # struct T207b
        #     x; y; z
        #     T207b(x, y; z = x) = new(x, y, z)
        # end
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @match T207b(1, 2) begin
                    T207b(x, y) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: The type `$T207b` has 3 fields but the pattern expects 2 fields."
            end
        end
    end

    @testset "attempt to match non-type 1" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @match Foo(1, 2) begin
                    ::1 => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Invalid type name: `1`."
            end
        end
    end

    @testset "attempt to match non-type 2" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @match Foo(1, 2) begin
                    ::Base => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Attempted to match non-type `Base` as a type."
            end
        end
    end

    @testset "bad match block syntax 1" begin
        let line = 0
            try
                line = (@__LINE__) + 1
                @eval @match a (b + c)
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Unrecognized @match block syntax: `b + c`."
            end
        end
    end

    @testset "bad match block syntax 2" begin
        let line = 0
            try
                line = (@__LINE__) + 1
                @eval @__match__ a (b + c)
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Unrecognized @match block syntax: `b + c`."
            end
        end
    end

    if VERSION >= v"1.8"
        @testset "warn for unreachable cases" begin
            let line = (@__LINE__) + 5
                @test_warn(
                    "$file:$line: Case 2: `Foo(1, 2) =>` is not reachable.",
                    @eval @match Foo(1, 2) begin
                        Foo(_, _) => 1
                        Foo(1, 2) => 2
                    end
                    )
            end
        end
    end

    if VERSION >= v"1.8"
        @testset "warn for unreachable cases with named tuples" begin
            let line = (@__LINE__) + 5
                @test_warn(
                    "$file:$line: Case 2: `(; x, y) =>` is not reachable.",
                    @eval @match Foo(1, 2) begin
                        (; x) => 1
                        (; x, y) => 2
                    end
                    )
            end
        end
    end

    @testset "assignment to pattern variables are permitted but act locally" begin
        @test (@match 1 begin
            x where begin
                @test x == 1
                x = 12
                @test x == 12
                true
            end => begin
                @test x == 1
                x = 13
                @test x == 13
                6
            end
        end) == 6
    end

    if VERSION >= v"1.8"
        @testset "type constraints on the input are observed" begin
            let line = (@__LINE__) + 7
                @test_warn(
                    "$file:$line: Case 4: `_ =>` is not reachable.",
                    @eval @match identity(BoolPair(true, false))::BoolPair begin
                        BoolPair(true, _)       => 1
                        BoolPair(_, true)       => 2
                        BoolPair(false, false)  => 3
                        _                       => 4 # unreachable
                    end
                    )
            end
        end
    end

    @testset "splatting interpolation is not supported" begin
        let line = 0
            try
                line = (@__LINE__) + 4
                Base.eval(@__MODULE__, @no_escape_quote begin
                    interp_values = [1, 2]
                    f(a) = @match a begin
                        [0, $(interp_values...), 3] => 1
                    end
                end)
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Splatting not supported in interpolation: `interp_values...`."
            end
        end
    end

    @testset "pattern variables are simple identifiers in a closed scope" begin
        @match collect(1:5) begin
            [x, y..., z] => begin
                @test @check_is_identifier(x)
                @test @check_is_identifier(y)
                @test @check_is_identifier(z)
                # test that pattern variable names are preserved in the code
                @test string(:(x + z)) == "x + z"
                @test x == 1
                @test y == [2, 3, 4]
                @test z == 5
                x = 3
                @test x == 3
                q = 12
            end
        end
        @test !(@isdefined x)
        @test !(@isdefined y)
        @test !(@isdefined z)
        @test !(@isdefined q)
    end

    @testset "pattern variable names can be shadowed" begin
        @match collect(1:5) begin
            [x, y..., z] => begin
                f(x) = x + 1
                @test f(x) == 2
                @test f(z) == 6
                @test x == 1
            end
        end
        @test !(@isdefined x)
    end

    @testset "pattern variable names can be assigned (locally)" begin
        z = "something"
        q = "other"
        @test (@match collect(1:5) begin
            [x, y..., z] where begin
                @test x == 1
                @test z == 5
                x = 55
                y = 2
                z = 100
                @test x == 55
                q = "changed"
                true
            end=> begin
                @test x == 1
                @test z == 5
                @test @isdefined y
                x + z
            end
        end) == 6
        @test !(@isdefined x)
        @test !(@isdefined y)
        @test z == "something"
        @test q == "changed"
    end

    @testset "disallow lazy strings in patterns due to their support of interpolation" begin
        z=3
        @test_throws LoadError (@eval @match z begin
            lazy"$(z)" => 1
            _ => 0
        end)
    end
end

@testset "ensure we use `isequal` and not `==`" begin
    function f(v)
        @match v begin
            0.0    => 1
            1.0    => 4
            -0.0   => 2
            _      => 3
        end
    end
    @test f(0.0) == 1
    @test f(1.0) == 4
    @test f(-0.0) == 2
    @test f(2.0) == 3
end

@testset "ensure that enums work" begin
    # @enum Color Yellow Blue Greed
    function f(v)
        @match v begin
            $Greed => "Greed is the color of money."
            _ => "other"
        end
    end
    @test f(Greed) == "Greed is the color of money."
    @test f(Yellow) == "other"
end

end
