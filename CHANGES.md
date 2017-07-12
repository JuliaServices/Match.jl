
v0.4.0 / 2017-07-11
==================

  * Update to run on julia v0.6
  * Bump REQUIRE to julia v0.6, update CI testing, coverage
  * Fix deprecation: takebuf_string(x) => String(take!(x))
  * Enable precompilation
  * Update tests
  * Update README badges, text
  * Whitespace fixes

v0.3.0 / 2016-09-13
==================

  * Additional Julia v0.5 deprecation updates
  * Replace "sub" with "view"

v0.2.4 / 2016-05-14
===================

  * Fix deprecation warnings on julia v0.5
  * Fix doc example formatting
  * Added examples to the documentation

v0.2.1 / 2016-01-12
===================

  * Fix RTD documentation generation

v0.2.0 / 2016-01-03
===================

  * Remove support for v0.3
  * Clean up tests for Julia v0.4
  * Supporting interpolated matches in quotes
  * Allow matches against ranges

v0.1.3 / 2015-04-03
===================

  * Fix fieldnames reference on Julia v0.3, update Compat requirement
  * Added PkgEval badge

v0.1.2 / 2015-04-01
===================

  * Added travis testing
  * Add ArrayViews as a dependency

v0.1.1 / 2015-03-30
===================

  * Fix zero-width glob
  * Fully remove Regex Matching from docs

v0.1.0 / 2015-03-30
===================

  * Misc cleanups
  * Added tests, fixes for @zachallaun's Match.jl examples
  * Update docs to remove Regex section
  * Rename viewdim -> slicedim, clean up generated code more
  * Fix match for v0.4, remove evals

v0.0.6 / 2015-01-30
===================

  * Fix tests to work with v0.4
  * Bump required julia version to v0.3
  * Use startswith instead of deprecated beginswith
  * Remove trailing whitespace

v0.0.5 / 2014-06-02
===================

  * Simplify regex, identity matching by defining Match.ismatch
  * Minor refactoring, updates to latest Julia changes

v0.0.4 / 2014-05-26
===================

  * Julia v0.2 compatibility: deleteat! was not defined in v0.2

v0.0.3 / 2014-03-02
===================

  * Fix #2.
  * Fix #8
  * Fix Regex expression matching
  * Fix up unsplatting, add tests
  * Make runtests runnable from anywhere
  * Allow matching against cell1d arrays.
  * Allow elipses once along any dimension, not just at end
  * Add @ismatch, simplify some expressions
  * Prevent infinite recursion in array matching.
  * Improve code generation for testing constant values.
  * Update exports, remove @fmatch, rename _fmatch -> fmatch
  * Fix matrix matching, update contains->in usage
  
  * Doc format updates
  * Fixes for ReadTheDocs/sphinx

  * README: Added links to scala examples
  * README.md: Acknowledge Zach's offer to use the Match.jl name for this package
  * Added references to other PatternMatching modules for Julia.
  * Updated README.md with many examples.  These should be moved to a manual.

