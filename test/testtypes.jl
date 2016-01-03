
#
# Address, Person types for deep match test
#

type Address
    street::AbstractString
    city::AbstractString
    zip::AbstractString
end

type Person
    firstname::AbstractString
    lastname::AbstractString
    address::Address
end

#
# Untyped lambda calculus definitions
#

abstract Term

immutable Var <: Term
    name::AbstractString
end

immutable Fun <: Term
    arg::AbstractString
    body::Term
end

immutable App <: Term
    f::Term
    v::Term
end
