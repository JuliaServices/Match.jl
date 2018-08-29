using Documenter
import Match

makedocs(modules=[Match],
    clean=false,
    format=:html,
    sitename="Match.jl",
    authors="Kevin Squire and contributors.",
    pages=[
        "Home" => "index.md"
    ],
    # Use clean URLs, unless built as a "local" build
    html_prettyurls=!("local" in ARGS),)

deploydocs(repo="github.com/kmsquire/Match.jl.git",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,)
