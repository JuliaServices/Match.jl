@testset "tests for the `@ismatch` macro" begin

    @testset "simple @ismatch cases 1" begin

        v = Foo(1, 2)
        if @ismatch v Foo(x, y)
            @test x == 1
            @test y == 2
        else
            @test false
        end
        @test x == 1

    end

    @testset "simple @ismatch cases 2" begin

        v = "something else"
        if @ismatch v Foo(x, y)
            @test false
        else
            @test !(@isdefined x)
            @test !(@isdefined y)
        end
        @test !(@isdefined x)
        @test !(@isdefined y)

    end

    @testset "@ismatch and `@match pattern = value` accept regex and other string-macro literals" begin

        @test @ismatch "abc" r"b"
        @test !(@ismatch "xyz" r"b")
        if @ismatch ("abc", 1) (r"^a", x)
            @test x == 1
        else
            @test false
        end
        @test @ismatch v"1.2.3" v"1.2.3"
        @test (@match r"b" = "abc") == "abc"
        @test_throws MatchFailure("xyz") @match r"b" = "xyz"

    end

end
