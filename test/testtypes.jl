
#
# Address, Person types for deep match test
#

type Address
    street::String
    city::String
    zip::String
end

type Person
    firstname::String
    lastname::String
    address::Address
end

#
# Untyped lambda calculus definitions
#

abstract Term

immutable Var <: Term
    name::String
end

immutable Fun <: Term
    arg::String
    body::Term
end

immutable App <: Term
    f::Term
    v::Term
end
