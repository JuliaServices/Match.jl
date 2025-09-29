var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#Match.jl-–-Advanced-Pattern-Matching-for-Julia-1",
    "page": "Home",
    "title": "Match.jl –- Advanced Pattern Matching for Julia",
    "category": "section",
    "text": "This package provides both simple and advanced pattern matching capabilities for Julia. Features include:Matching against almost any data type with a first-match policy\nDeep matching within data types and matrices\nVariable binding within matches"
},

{
    "location": "#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "Use the Julia package manager. Within Julia, do:Pkg.add(\"Match\")"
},

{
    "location": "#Usage-1",
    "page": "Home",
    "title": "Usage",
    "category": "section",
    "text": "The package provides one macro, @match, which can be used as:using Match\n\n@match item begin\n    pattern1              => result1\n    pattern2, if cond end => result2\n    pattern3 || pattern4  => result3\n    _                     => default_result\nendPatterns can be values, regular expressions, type checks or constructors, tuples, or arrays, including multidimensional arrays. It is possible to supply variables inside pattern, which will be bound to corresponding values. This and other features are best seen with examples."
},

{
    "location": "#Match-Values-1",
    "page": "Home",
    "title": "Match Values",
    "category": "section",
    "text": "The easiest kind of matching to use is simply to match against values:@match item begin\n   1 => \"one\"\n   2 => \"two\"\n   _ => \"Something else...\"\nend"
},

{
    "location": "#Match-Types-1",
    "page": "Home",
    "title": "Match Types",
    "category": "section",
    "text": "Julia already does a great job of this with functions and multiple dispatch, and it is generally be better to use those mechanisms when possible. But it can be done here:julia> matchtype(item) = @match item begin\n           n::Int               => println(\"Integers are awesome!\")\n           str::String          => println(\"Strings are the best\")\n           m::Dict{Int, String} => println(\"Ints for Strings?\")\n           d::Dict              => println(\"A Dict! Looking up a word?\")\n           _                    => println(\"Something unexpected\")\n   end\n\njulia> matchtype(66)\nIntegers are awesome!\n\njulia> matchtype(\"abc\")\nStrings are the best\n\njulia> matchtype(Dict{Int, String}(1=>\"a\",2=>\"b\"))\nInts for Strings?\n\njulia> matchtype(Dict())\nA Dict! Looking up a word?\n\njulia> matchtype(2.0)\nSomething unexpected"
},

{
    "location": "#Deep-Matching-of-Composite-Types-1",
    "page": "Home",
    "title": "Deep Matching of Composite Types",
    "category": "section",
    "text": "One nice feature is the ability to match embedded types, as well as bind variables to components of those types:struct Address\n    street::String\n    city::String\n    zip::String\nend\n\nstruct Person\n    firstname::String\n    lastname::String\n    address::Address\nend\n\npersoninfo(person) = @match person begin\n  Person(\"Julia\", lname,  _)           => \"Found Julia $lname\"\n  Person(fname, \"Julia\", _)            => \"$fname Julia was here!\"\n  Person(fname, lname,\n         Address(_, \"Cambridge\", zip)) => \"$fname $lname lives in zip $zip\"\n  Person(_...)                         => \"Unknown person!\"\nend\n\njulia> personinfo(Person(\"Julia\", \"Robinson\",\n                  Address(\"450 Serra Mall\", \"Stanford\", \"94305\")))\n\"Found Julia Robinson\"\n\njulia> personinfo(Person(\"Gaston\", \"Julia\",\n                  Address(\"1 rue Victor Cousin\", \"Paris\", \"75005\")))\n\"Gaston Julia was here!\"\n\njulia> personinfo(Person(\"Edwin\", \"Aldrin\",\n                  Address(\"350 Memorial Dr\", \"Cambridge\", \"02139\")))\n\"Edwin Aldrin lives in zip 02139\"\n\njulia> personinfo(Person(\"Linus\", \"Pauling\",\n                  Address(\"1200 E California Blvd\", \"Pasadena\", \"91125\")))\n\"Unknown person!\""
},

{
    "location": "#Alternatives-and-Guards-1",
    "page": "Home",
    "title": "Alternatives and Guards",
    "category": "section",
    "text": "Alternatives allow a match against multiple patterns.Guards allow a conditional match. They are not a standard part of Julia yet, so to get the parser to accept them requires that they are preceded by a comma and end with \"end\":function parse_arg(arg::String, value::Any=nothing)\n  @match (arg, value) begin\n    (\"-l\",              lang)    => println(\"Language set to $lang\")\n    (\"-o\" || \"--optim\", n::Int),\n     if 0 < n <= 5 end           => println(\"Optimization level set to $n\")\n    (\"-o\" || \"--optim\", n::Int)  => println(\"Illegal optimization level $(n)!\")\n    (\"-h\" || \"--help\",  nothing) => println(\"Help!\")\n    bad                          => println(\"Unknown argument: $bad\")\n  end\nend\n\njulia> parse_arg(\"-l\", \"eng\")\nLanguage set to eng\n\njulia> parse_arg(\"-l\")\nUnknown argument: (\"-l\",nothing)\n\njulia> parse_arg(\"-o\", 4)\nOptimization level set to 4\n\njulia> parse_arg(\"--optim\", 5)\nOptimization level set to 5\n\njulia> parse_arg(\"-o\", 0)\nIllegal optimization level 0!\n\njulia> parse_arg(\"-o\", 1.0)\nUnknown argument: (\"-o\",1.0)\n\njulia> parse_arg(\"-h\")\nHelp!\n\njulia> parse_arg(\"--help\")\nHelp!"
},

{
    "location": "#Match-Ranges-1",
    "page": "Home",
    "title": "Match Ranges",
    "category": "section",
    "text": "Borrowing a nice idea from pattern matching in Rust, pattern matching against ranges is also supported:julia> function num_match(n)\n           @match n begin\n               0      => \"zero\"\n               1 || 2 => \"one or two\"\n               3:10   => \"three to ten\"\n               _      => \"something else\"\n           end\n       end\nnum_match (generic function with 1 method)\n\njulia> num_match(0)\n\"zero\"\n\njulia> num_match(2)\n\"one or two\"\n\njulia> num_match(12)\n\"something else\"\n\njulia> num_match('c')\n\"something else\"Note that a range can still match another range exactly:julia> num_match(3:10)\n\"three to ten\""
},

{
    "location": "#Regular-Expressions-1",
    "page": "Home",
    "title": "Regular Expressions",
    "category": "section",
    "text": "Match.jl used to have complex regular expression handling, but it was implemented using eval, which is generally a bad idea and was the source of some undesirable behavior.With some work, it may be possible to reimplement, but it's unclear if this is a good idea yet."
},

{
    "location": "#Deep-Matching-Against-Arrays-1",
    "page": "Home",
    "title": "Deep Matching Against Arrays",
    "category": "section",
    "text": "Arrays are intrinsic components of Julia. Match allows deep matching against arrays.The following examples also demonstrate how Match can be used strictly for its extraction/binding capabilities, by only matching against one pattern."
},

{
    "location": "#Extract-first-element,-rest-of-vector-1",
    "page": "Home",
    "title": "Extract first element, rest of vector",
    "category": "section",
    "text": "julia> @match([1:4], [a,b...]);\n\njulia> a\n1\n\njulia> b\n3-element SubArray{Int64,1,Array{Int64,1},(Range1{Int64},)}:\n 2\n 3\n 4"
},

{
    "location": "#Match-values-at-the-beginning-of-a-vector-1",
    "page": "Home",
    "title": "Match values at the beginning of a vector",
    "category": "section",
    "text": "julia> @match([1:5], [1,2,a...])\n 3-element SubArray{Int64,1,Array{Int64,1},(Range1{Int64},)}:\n  3\n  4\n  5"
},

{
    "location": "#Match-and-collect-columns-1",
    "page": "Home",
    "title": "Match and collect columns",
    "category": "section",
    "text": "julia> @match([1 2 3; 4 5 6], [a b...]);\n\njulia> a\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 1\n 4\n\njulia> b\n2x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 2 3\n 5 6\n\njulia> @match([1 2 3; 4 5 6], [a b c]);\n\njulia> a\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 1\n 4\n\njulia> b\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 2\n 5\n\njulia> c\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 3\n 6\n\njulia> @match([1 2 3; 4 5 6], [[1,4] a b]);\n\njulia> a\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 2\n 5\n\njulia> b\n2-element SubArray{Int64,1,Array{Int64,2},(Range1{Int64},Int64)}:\n 3\n 6"
},

{
    "location": "#Match-and-collect-rows-1",
    "page": "Home",
    "title": "Match and collect rows",
    "category": "section",
    "text": "julia> @match([1 2 3; 4 5 6], [a, b]);\n\njulia> a\n1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 1 2 3\n\njulia> b\n1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 4 5 6\n\njulia> @match([1 2 3; 4 5 6; 7 8 9], [a, b...]);\n\njulia> a\n1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 1 2 3\n\njulia> b\n2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 4 5 6\n 7 8 9\n\njulia> @match([1 2 3; 4 5 6], [[1 2 3], a])\n1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 4  5  6\n\njulia> @match([1 2 3; 4 5 6], [1 2 3; a])\n1x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 4  5  6\n\njulia> @match([1 2 3; 4 5 6; 7 8 9], [1 2 3; a...])\n2x3 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 4  5  6\n 7  8  9"
},

{
    "location": "#Match-individual-positions-1",
    "page": "Home",
    "title": "Match individual positions",
    "category": "section",
    "text": "julia> @match([1 2; 3 4], [1 a; b c]);\n\njulia> a\n2\n\njulia> b\n3\n\njulia> c\n4\n\njulia> @match([1 2; 3 4], [1 a; b...]);\n\njulia> a\n2\n\njulia> b\n1x2 SubArray{Int64,2,Array{Int64,2},(Range1{Int64},Range1{Int64})}:\n 3 4"
},

{
    "location": "#Match-3D-arrays-1",
    "page": "Home",
    "title": "Match 3D arrays",
    "category": "section",
    "text": "julia> m = reshape([1:8], (2,2,2))\n2x2x2 Array{Int64,3}:\n[:, :, 1] =\n 1 3\n 2 4\n\n[:, :, 2] =\n 5 7\n 6 8\n\njulia> @match(m, [a b]);\n\njulia> a\n2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:\n 1 3\n 2 4\n\njulia> b\n2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:\n 5 7\n 6 8\n\njulia> @match(m, [[1 a; b c] d]);\n\njulia> a\n3\n\njulia> b\n2\n\njulia> c\n4\n\njulia> d\n2x2 SubArray{Int64,2,Array{Int64,3},(Range1{Int64},Range1{Int64},Int64)}:\n 5 7\n 6 8"
},

{
    "location": "#Notes/Gotchas-1",
    "page": "Home",
    "title": "Notes/Gotchas",
    "category": "section",
    "text": "There are a few useful things to be aware of when using Match.Guards need a comma and an `end`:\nBad\n  julia> _iseven(a) = @match a begin\n          n::Int if n%2 == 0 end => println(\"$n is even\")\n          m::Int                 => println(\"$m is odd\")\n      end\n  ERROR: syntax: extra token \"if\" after end of expression\n\n  julia> _iseven(a) = @match a begin\n          n::Int, if n%2 == 0 => println(\"$n is even\")\n          m::Int              => println(\"$m is odd\")\n      end\n  ERROR: syntax: invalid identifier name =>\nGood\n  julia> _iseven(a) = @match a begin\n          n::Int, if n%2 == 0 end => println(\"$n is even\")\n          m::Int                  => println(\"$m is odd\")\n      end\n  # methods for generic function _iseven\n  _iseven(a) at none:1\nWithout a default match, the result is `nothing`:\n  julia> test(a) = @match a begin\n              n::Int           => \"Integer\"\n              m::FloatingPoint => \"Float\"\n          end\n\n  julia> test(\"Julia is great\")\n\n  julia>\nIn Scala, _ is a wildcard pattern which matches anything, and is not bound as a variable.\nIn Match for Julia, _ can be used as a wildcard, and will be bound to the last use if it is referenced in the result expression:\n  julia> test(a) = @match a begin\n              n::Int           => \"Integer\"\n              _::FloatingPoint => \"$_ is a Float\"\n              (_,_)            => \"$_ is the second part of a tuple\"\n          end\n\n  julia> test(1.0)\n  \"1.0 is a Float\"\n\n  julia> test((1,2))\n  \"2 is the second part of a tuple\"\nNote that variables not referenced in the result expression will not be bound (e.g., n is never bound above). One small exception to this rule is that when \"=&gt;\" is not used, \"_\" will not be assigned.\nIf you want to see the code generated for a macro, you can use `macroexpand`:\n  julia> macroexpand(:(@match(a, begin\n                          n::Int           => \"Integer\"\n                              m::FloatingPoint => \"Float\"\n                          end))\n  quote  # REPL[1], line 2:\n      if isa(a,Int) # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 387:\n          \"Integer\"\n      else  # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 389:\n          begin  # REPL[1], line 3:\n              if isa(a,FloatingPoint) # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 387:\n                  \"Float\"\n              else  # /Users/kevin/.julia/v0.5/Match/src/matchmacro.jl, line 389:\n                  nothing\n              end\n          end\n      end\n  end"
},

{
    "location": "#Examples-1",
    "page": "Home",
    "title": "Examples",
    "category": "section",
    "text": "Here are a couple of additional examples."
},

{
    "location": "#Mathematica-Inspired-Sparse-Array-Constructor-1",
    "page": "Home",
    "title": "Mathematica-Inspired Sparse Array Constructor",
    "category": "section",
    "text": "Contributed by @benkjI've realized that Match.jl is perfect for creating in Julia an equivalent of SparseArray which I find quite useful in Mathematica.My basic implementation is this:macro sparsearray(size, rule)\n    return quote\n        _A = spzeros($size...)\n        $(push!(rule.args, :(_ => 0)))\n\n        for _itr in eachindex(_A)\n            _A[_itr] = @match(_itr.I, $rule)\n        end\n        _A\n    end\nendExample:julia> A = @sparsearray (5,5)  begin\n               (n,m), if n==m+1 end => m\n               (n,m), if n==m-1 end => n+10\n               (1,5) => 1\n       endwhich creates the matrix:julia> full(A)\n5x5 Array{Float64,2}:\n 0.0  11.0   0.0   0.0   1.0\n 1.0   0.0  12.0   0.0   0.0\n 0.0   2.0   0.0  13.0   0.0\n 0.0   0.0   3.0   0.0  14.0\n 0.0   0.0   0.0   4.0   0.0"
},

{
    "location": "#Matching-Exprs-1",
    "page": "Home",
    "title": "Matching Exprs",
    "category": "section",
    "text": "The @match macro can be used to match Julia expressions (Expr objects). One issue is that the internal structure of Expr objects doesn't match their constructor exactly, so one has to put arguments in brackets, as well as capture the typ field of macros.The following function is a nice example of matching expressions. It is used in VideoIO.jl to extract the names of expressions generated by Clang.jl, for later filtering and rewriting.:extract_name(x) = string(x)\nfunction extract_name(e::Expr)\n    @match e begin\n        Expr(:type,      [_, name, _], _)     => name\n        Expr(:typealias, [name, _], _)        => name\n        Expr(:call,      [name, _...], _)     => name\n        Expr(:function,  [sig, _...], _)      => extract_name(sig)\n        Expr(:const,     [assn, _...], _)     => extract_name(assn)\n        Expr(:(=),       [fn, body, _...], _) => extract_name(fn)\n        Expr(expr_type,  _...)                => error(\"Can't extract name from \",\n                                                        expr_type, \" expression:\\n\",\n                                                        \"    $e\\n\")\n    end\nend"
},

{
    "location": "#Inspiration-1",
    "page": "Home",
    "title": "Inspiration",
    "category": "section",
    "text": "The following pages on pattern matching in scala provided inspiration for the library:http://thecodegeneral.wordpress.com/2012/03/25/switch-statements-on-steroids-scala-pattern-matching/\nhttp://java.dzone.com/articles/scala-pattern-matching-case\nhttp://kerflyn.wordpress.com/2011/02/14/playing-with-scalas-pattern-matching/\nhttp://docs.scala-lang.org/tutorials/tour/case-classes.html"
},

]}
