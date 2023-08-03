# This data type makes it easier to avoid accidentally mutating a vector that was
# intended to be immutable.  Use instead of `Vector{T}` when you intend it to be
# immutable.
struct ImmutableVector{T} <: AbstractVector{T}
    _data::Vector{T}
    _cached_hash::UInt64
    ImmutableVector{T}(data::Vector{T}) where {T} = new(copy(data), hash(data, 0xdc8f7e8a0e698fac))
end
ImmutableVector(data::Vector{T}) where {T} = ImmutableVector{T}(data)
Base.size(a::ImmutableVector) = size(a._data)
Base.length(a::ImmutableVector) = length(a._data)::Int
Base.getindex(a::ImmutableVector{T}, i::Int) where {T} = a._data[i]::T
Base.getindex(a::ImmutableVector{T}, i::UnitRange{Int}) where {T} = ImmutableVector{T}(a._data[i])
Base.eachindex(a::ImmutableVector) = 1:length(a)
Base.IndexStyle(::Type{<:ImmutableVector}) = IndexLinear()
Base.convert(::Type{ImmutableVector{T}}, x::Vector{T}) where {T} = ImmutableVector{T}(x)
Base.hash(a::ImmutableVector{T}, h::UInt64) where {T} = hash(a._cached_hash, h)
function Base.:(==)(a::ImmutableVector{T}, b::ImmutableVector{T}) where {T}
    isequal(a._cached_hash, b._cached_hash) && isequal(a._data, b._data)
end
