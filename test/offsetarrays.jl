@testset "Array patterns use native indices" begin
    fixed(x) = @match x begin
        [a, b, c] => (a, b, c)
        _ => nothing
    end
    prefix(x) = @match x begin
        [a, rest...] => (a, rest)
        _ => nothing
    end
    suffix(x) = @match x begin
        [rest..., z] => (rest, z)
        _ => nothing
    end
    middle(x) = @match x begin
        [a, rest..., z] => (a, rest, z)
        _ => nothing
    end
    whole(x) = @match x begin
        [rest...] => rest
    end

    for start in (-4, 0, 4), n in 0:4
        values = collect(1:n)
        input = OffsetArray(values, start:(start + n - 1))
        @test fixed(input) == (n == 3 ? (1, 2, 3) : nothing)
        @test prefix(input) == (n == 0 ? nothing : (1, values[2:end]))
        @test suffix(input) == (n == 0 ? nothing : (values[1:end-1], n))
        @test middle(input) == (n < 2 ? nothing : (1, values[2:end-1], n))
        @test whole(input) == values
    end

    input = OffsetArray([1, 2, 3], -2:0)
    edges(x) = @match x begin [a, rest..., z] => (a, z) end
    @test @inferred(edges(input)) == (1, 3)
    @test fixed([1, 2, 3]) == (1, 2, 3)
    @test middle([1, 2, 3]) == (1, [2], 3)
    @test (@match (1, 2, 3) begin (a, rest..., z) => (a, rest, z) end) == (1, (2,), 3)
    @test (@match () begin (rest...,) => rest end) == ()

    nested = OffsetArray([input, 4], 0:1)
    @test (@match nested begin [[a, rest...], z] => (a, rest, z) end) == (1, [2, 3], 4)
    matrix = OffsetArray(reshape(collect(1:4), 2, 2), -2:-1, 4:5)
    @test (@match matrix begin [a, b, c, d] => (a, b, c, d) end) == (1, 2, 3, 4)

    let firstindex = nothing, lastindex = nothing, length = nothing
        @test (@match input begin [a, rest..., z] => (a, rest, z) end) == (1, [2], 3)
    end
end
