#
# Additional tests to improve node coverage.
# These tests mainly exercise diagnostic code that isn't crucial to the
# normal operation of the package.
#

abstract type A; end
struct B <: A; end
struct C <: A; end
struct D; x; end

abstract type Abstract1; end
abstract type Abstract2; end

struct TrashFetchPattern <: Match.BoundFetchPattern
    location::LineNumberNode
end
struct TrashPattern <: Match.BoundPattern
    location::LineNumberNode
end
Match.pretty(io::IO, ::TrashPattern) = print(io, "TrashPattern")
const T = 12

struct MyPair
    x
    y
end
Match.match_fieldnames(::Type{MyPair}) = error("May not @match MyPair")

macro match_case(pattern, value)
    return esc(:($pattern => $value))
end

expected="""
Decision Automaton: (57 nodes) input «input_value»
Node 1
  1: @ismatch(«input_value», 1) => 1
  2: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && isequal(«input_value.y», [x => «input_value.x»] x)) => 2
  3: «input_value» isa Main.Rematch2Tests.D => 3
  4: («input_value» isa AbstractArray && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  5: («input_value» isa Tuple && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
  10: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && @ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && @ismatch(«input_value.x», 1) && «input_value.y» := «input_value».y && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && «where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST @ismatch(«input_value», 1)
    THEN: Node 2 (fall through)
    ELSE: Node 3
Node 2
  1: true => 1
    MATCH 1 with value 1
Node 3
  2: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && isequal(«input_value.y», [x => «input_value.x»] x)) => 2
  3: «input_value» isa Main.Rematch2Tests.D => 3
  4: («input_value» isa AbstractArray && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  5: («input_value» isa Tuple && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
  10: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && @ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && @ismatch(«input_value.x», 1) && «input_value.y» := «input_value».y && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («input_value» isa Main.Rematch2Tests.Foo && «input_value.x» := «input_value».x && «input_value.y» := «input_value».y && «where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST «input_value» isa Main.Rematch2Tests.Foo
    THEN: Node 4 (fall through)
    ELSE: Node 26
Node 4
  2: («input_value.x» := «input_value».x && «input_value.y» := «input_value».y && isequal(«input_value.y», [x => «input_value.x»] x)) => 2
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  10: («input_value.x» := «input_value».x && «input_value.y» := «input_value».y && @ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: («input_value.x» := «input_value».x && @ismatch(«input_value.x», 1) && «input_value.y» := «input_value».y && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («input_value.x» := «input_value».x && «input_value.y» := «input_value».y && «where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «input_value.x» := «input_value».x
    NEXT: Node 5 (fall through)
Node 5
  2: («input_value.y» := «input_value».y && isequal(«input_value.y», [x => «input_value.x»] x)) => 2
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  10: («input_value.y» := «input_value».y && @ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «input_value.y» := «input_value».y && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («input_value.y» := «input_value».y && «where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «input_value.y» := «input_value».y
    NEXT: Node 6 (fall through)
Node 6
  2: isequal(«input_value.y», [x => «input_value.x»] x) => 2
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  10: (@ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST isequal(«input_value.y», [x => «input_value.x»] x)
    THEN: Node 7 (fall through)
    ELSE: Node 8
Node 7
  2: true => 2
    MATCH 2 with value 2
Node 8
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  10: (@ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST @ismatch(«input_value», 6)
    THEN: Node 44
    ELSE: Node 9
Node 9
  6: @ismatch(«input_value», 7) => 6
  10: (@ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST @ismatch(«input_value», 7)
    THEN: Node 44
    ELSE: Node 10
Node 10
  10: (@ismatch(«input_value.y», 2) && «where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST @ismatch(«input_value.y», 2)
    THEN: Node 11 (fall through)
    ELSE: Node 17
Node 11
  10: («where_4» := [x => «input_value.x»] f1(x) && «where_4») => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «where_4» := [x => «input_value.x»] f1(x)
    NEXT: Node 12 (fall through)
Node 12
  10: «where_4» => 1
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST «where_4»
    THEN: Node 13 (fall through)
    ELSE: Node 14
Node 13
  10: true => 1
    MATCH 10 with value 1
Node 14
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
    TEST @ismatch(«input_value.x», 1)
    THEN: Node 15 (fall through)
    ELSE: Node 57
Node 15
  11: («where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
    FETCH «where_5» := [y => «input_value.y»] f2(y)
    NEXT: Node 16 (fall through)
Node 16
  11: «where_5» => 2
    TEST «where_5»
    THEN: Node 20
    ELSE: Node 57
Node 17
  11: (@ismatch(«input_value.x», 1) && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST @ismatch(«input_value.x», 1)
    THEN: Node 18 (fall through)
    ELSE: Node 21
Node 18
  11: («where_5» := [y => «input_value.y»] f2(y) && «where_5») => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «where_5» := [y => «input_value.y»] f2(y)
    NEXT: Node 19 (fall through)
Node 19
  11: «where_5» => 2
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5») => 3
    TEST «where_5»
    THEN: Node 20 (fall through)
    ELSE: Node 57
Node 20
  11: true => 2
    MATCH 11 with value 2
Node 21
  12: («where_4» := [x => «input_value.x»] f1(x) && «where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «where_4» := [x => «input_value.x»] f1(x)
    NEXT: Node 22 (fall through)
Node 22
  12: («where_4» && «where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    TEST «where_4»
    THEN: Node 23 (fall through)
    ELSE: Node 57
Node 23
  12: («where_5» := [y => «input_value.y»] f2(y) && «where_5») => 3
    FETCH «where_5» := [y => «input_value.y»] f2(y)
    NEXT: Node 24 (fall through)
Node 24
  12: «where_5» => 3
    TEST «where_5»
    THEN: Node 25 (fall through)
    ELSE: Node 57
Node 25
  12: true => 3
    MATCH 12 with value 3
Node 26
  3: «input_value» isa Main.Rematch2Tests.D => 3
  4: («input_value» isa AbstractArray && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  5: («input_value» isa Tuple && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa Main.Rematch2Tests.D
    THEN: Node 27 (fall through)
    ELSE: Node 28
Node 27
  3: true => 3
    MATCH 3 with value 3
Node 28
  4: («input_value» isa AbstractArray && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  5: («input_value» isa Tuple && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa AbstractArray
    THEN: Node 29 (fall through)
    ELSE: Node 33
Node 29
  4: («length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    FETCH «length(input_value)» := length(«input_value»)
    NEXT: Node 30 (fall through)
Node 30
  4: («length(input_value)» >= 2 && «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]) => [y => «input_value[2:(length-1)]»] y
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    TEST «length(input_value)» >= 2
    THEN: Node 31 (fall through)
    ELSE: Node 40
Node 31
  4: «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)] => [y => «input_value[2:(length-1)]»] y
    FETCH «input_value[2:(length-1)]» := «input_value»[2:(length(«input_value»)-1)]
    NEXT: Node 32 (fall through)
Node 32
  4: true => [y => «input_value[2:(length-1)]»] y
    MATCH 4 with value [y => «input_value[2:(length-1)]»] y
Node 33
  5: («input_value» isa Tuple && «length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa Tuple
    THEN: Node 34 (fall through)
    ELSE: Node 42
Node 34
  5: («length(input_value)» := length(«input_value») && «length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    FETCH «length(input_value)» := length(«input_value»)
    NEXT: Node 35 (fall through)
Node 35
  5: («length(input_value)» >= 2 && «input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    TEST «length(input_value)» >= 2
    THEN: Node 36 (fall through)
    ELSE: Node 40
Node 36
  5: («input_value[-1]» := «input_value»[-1] && «where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    FETCH «input_value[-1]» := «input_value»[-1]
    NEXT: Node 37 (fall through)
Node 37
  5: («where_0» := e.q1 && «where_0») => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    FETCH «where_0» := e.q1
    NEXT: Node 38 (fall through)
Node 38
  5: «where_0» => [z => «input_value[-1]»] z
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    TEST «where_0»
    THEN: Node 39 (fall through)
    ELSE: Node 40
Node 39
  5: true => [z => «input_value[-1]»] z
    MATCH 5 with value [z => «input_value[-1]»] z
Node 40
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
    TEST @ismatch(«input_value», 6)
    THEN: Node 44
    ELSE: Node 41
Node 41
  6: @ismatch(«input_value», 7) => 6
    TEST @ismatch(«input_value», 7)
    THEN: Node 44
    ELSE: Node 57
Node 42
  6: (@ismatch(«input_value», 6) || @ismatch(«input_value», 7)) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST @ismatch(«input_value», 6)
    THEN: Node 44
    ELSE: Node 43
Node 43
  6: @ismatch(«input_value», 7) => 6
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST @ismatch(«input_value», 7)
    THEN: Node 44 (fall through)
    ELSE: Node 45
Node 44
  6: true => 6
    MATCH 6 with value 6
Node 45
  7: («input_value» isa Main.Rematch2Tests.A && «where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa Main.Rematch2Tests.A
    THEN: Node 46 (fall through)
    ELSE: Node 57
Node 46
  7: («where_1» := e.q2 && «where_1») => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    FETCH «where_1» := e.q2
    NEXT: Node 47 (fall through)
Node 47
  7: «where_1» => 7
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «where_1»
    THEN: Node 48 (fall through)
    ELSE: Node 49
Node 48
  7: true => 7
    MATCH 7 with value 7
Node 49
  8: («input_value» isa Main.Rematch2Tests.B && «where_2» := e.q3 && «where_2») => 8
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa Main.Rematch2Tests.B
    THEN: Node 50 (fall through)
    ELSE: Node 53
Node 50
  8: («where_2» := e.q3 && «where_2») => 8
    FETCH «where_2» := e.q3
    NEXT: Node 51 (fall through)
Node 51
  8: «where_2» => 8
    TEST «where_2»
    THEN: Node 52 (fall through)
    ELSE: Node 57
Node 52
  8: true => 8
    MATCH 8 with value 8
Node 53
  9: («input_value» isa Main.Rematch2Tests.C && «where_3» := e.q4 && «where_3») => 9
    TEST «input_value» isa Main.Rematch2Tests.C
    THEN: Node 54 (fall through)
    ELSE: Node 57
Node 54
  9: («where_3» := e.q4 && «where_3») => 9
    FETCH «where_3» := e.q4
    NEXT: Node 55 (fall through)
Node 55
  9: «where_3» => 9
    TEST «where_3»
    THEN: Node 56 (fall through)
    ELSE: Node 57
Node 56
  9: true => 9
    MATCH 9 with value 9
Node 57
    FAIL (throw)((Match.MatchFailure)(var"«input_value»"))
end # of automaton
"""
@testset "Tests for node coverage" begin
    @testset "exercise dumpall 1" begin
        devnull = IOBuffer()
        Match.@match_dumpall devnull e begin
            1                            => 1
            Foo(x, x)                    => 2
            y::D                         => 3
            [x, y..., z]                 => y
            (x, y..., z) where e.q1      => z
            6 || 7                       => 6
            (x::A) where e.q2            => 7
            (x::B) where e.q3            => 8
            (x::C) where e.q4            => 9
            Foo(x, 2) where f1(x)            => 1
            Foo(1, y) where f2(y)            => 2
            Foo(x, y) where (f1(x) && f2(y)) => 3
        end
        actual = String(take!(devnull))
        for (a, e) in zip(split(actual, '\n'), split(expected, '\n'))
            @test a == e
        end
    end

    @testset "exercise dumpall 2" begin
        devnull = IOBuffer()
        Match.@match_dumpall devnull some_value begin
            Foo(x, 2) where !f1(x)            => 1
            Foo(1, y) where !f2(y)            => 2
            Foo(x, y) where !(f1(x) || f2(y)) => 3
            _                                 => 5
        end
        Match.@match_dump devnull some_value begin
            Foo(x, 2) where !f1(x)            => 1
            Foo(1, y) where !f2(y)            => 2
            Foo(x, y) where !(f1(x) || f2(y)) => 3
            _                                 => 5
        end
    end

    @testset "exercise dumpall 3" begin
        devnull = IOBuffer()
        Match.@match_dumpall devnull some_value begin
            Diff(_) => 1
            _ => 2
        end
        Match.@match_dump devnull some_value begin
            Diff(_) => 1
            _ => 2
        end
    end

    @testset "trigger some normally unreachable code 1" begin
        @test_throws ErrorException Match.gentemp(:a)

        trash = TrashFetchPattern(LineNumberNode(@__LINE__, @__FILE__))
        binder = Match.BinderContext(@__MODULE__)
        @test_throws ErrorException Match.code(trash)
        @test_throws ErrorException Match.code(trash, binder)
        @test_throws ErrorException Match.pretty(stdout, trash)
        @test_throws LoadError @eval begin
            x=123
            Match.@ismatch x (1:(2+3))
        end
    end

    @testset "trigger some normally unreachable code 2" begin
        # Simplification of patterns should not normally get into a position where it can
        # discard an unneeded `BoundFetchExpressionPattern` because that pattern is
        # produced at the same time as another node that consumes its result.  However,
        # the code is written to handle this case anyway.  Here we force that code to
        # be exercised and verify the correct result if it were to somehow happen.
        location = LineNumberNode(@__LINE__, @__FILE__)
        expr = Match.BoundExpression(location, 1)
        pattern = Match.BoundFetchExpressionPattern(expr, nothing, Int)
        binder = Match.BinderContext(@__MODULE__)
        @test Match.simplify(pattern, Set{Symbol}(), binder) isa Match.BoundTruePattern
    end

    @testset "trigger some normally unreachable code 3" begin
        location = LineNumberNode(@__LINE__, @__FILE__)
        action = TrashPattern(location)
        result = Match.BoundExpression(location, 2)
        node = Match.DeduplicatedAutomatonNode(action, ())
        binder = Match.BinderContext(@__MODULE__)
        @test_throws ErrorException Match.generate_code([node], :x, location, binder)
    end

    function f300(x::T) where { T }
        # The implementation of @match can't bind `T` below - it finds the non-type `T`
        # at module level - so it ignores it.
        return @match x::T begin
            _ => 1
        end
    end
    @test f300(1) == 1

    @testset "Match.match_fieldnames(...) throwing" begin
        let line = 0, file = @__FILE__
            try
                line = (@__LINE__) + 2
                @eval @match MyPair(1, 2) begin
                    MyPair(1, 2) => 3
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "May not @match MyPair"
            end
        end
    end

    @testset "A macro that expands to a match case" begin
        # macro match_case(pattern, value)
        #     return esc(:(x => value))
        # end
        @test (@match :x begin
            @match_case pattern 1
        end) == 1
        @test (@__match__ :x begin
            @match_case pattern 1
        end) == 1
    end

    @testset "Some unlikely code" begin
        @test (@match 1 begin
            ::Int && ::Int => 1
        end) == 1

        @test_throws LoadError @eval (@match true begin
            x::Bool, if x; true; end => 1
        end)
    end

    @testset "Some other normally unreachable code 1" begin
        location = LineNumberNode(@__LINE__, @__FILE__)
        f = Match.BoundFalsePattern(location, false)
        @test_throws ErrorException Match.next_action(f)

        devnull = IOBuffer()
        node = Match.AutomatonNode(Match.BoundCase[])
        pattern = TrashFetchPattern(location)
        binder = Match.BinderContext(@__MODULE__)
        @test_throws ErrorException Match.make_next(node, pattern, binder)
        @test_throws ErrorException Match.pretty(devnull, pattern)

        f = Match.BoundFalsePattern(location, false)
        @test Match.pretty(f) == "false"
        @test f == f

        function pretty(node::T, binder) where { T }
            io = IOBuffer()
            numberer = IdDict{T, Int}()
            numberer[node] = 0
            Match.pretty(io, node, binder, numberer, true)
            String(take!(io))
        end
        node = Match.AutomatonNode(Match.BoundCase[])
        @test pretty(node, binder) == "Node 0\n   "
        node.action = TrashPattern(location)
        @test pretty(node, binder) == "Node 0\n   TrashPattern"
        pattern = TrashPattern(location)
        @test_throws ErrorException Match.make_next(node, pattern, binder)
    end

    @testset "Abstract types" begin
        x = 2
        @test (@__match__ x begin
            ::Abstract1 => 1
            ::Abstract2 => 2
            _ => 3
        end) == 3
        @test (@match x begin
            ::Abstract1 => 1
            ::Abstract2 => 2
            _ => 3
        end) == 3
    end

    @testset "Nested use of @match" begin
        @test (@match 1 begin
            x => @match 2 begin
                2 => 3x
            end
        end) == 3
    end

    @testset "immutable vector" begin
        iv = Match.ImmutableVector([1, 2, 3, 4, 5])
        @test iv[2:3] == Match.ImmutableVector([2, 3])
        h = hash(iv, UInt(0x12))
        @test h isa UInt
    end

    @testset "Test the test macro @__match__" begin
        @test (@__match__ 1 begin
            1 || 2 => 2
        end) == 2
        @test @__match__(1, 1 => 2) == 2
    end

    @testset "Test trivial conditions" begin
        @test (@__match__ 1 begin
            _ => 2
        end) == 2
        @test @__match__(1, _ => 2) == 2
    end
end # @testset "Tests that add code coverage"
