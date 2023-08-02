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

end
