# Package

version       = "0.2.0"
author        = "hlaaftana"
description   = "instantiated \"pointers\" to cached AST"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.20.0"

import os

when (compiles do: import nimbleutils):
  import nimbleutils

task docs, "build docs for all modules":
  when declared(buildDocs):
    buildDocs(gitUrl = "https://github.com/hlaaftana/applicates")
  else:
    echo "docs task not implemented, need nimbleutils"

task tests, "run tests for multiple backends and defines":
  when declared(runTests):
    runTests(
      # set to only js or only c for less runs:
      backends = {c, js}, 
      # these defines are pretty stable, comment this out for less runs:
      optionCombos = @["", "-d:applicatesUseMacroCache", "-d:applicatesCacheUseTable"]
    )
  else:
    echo "tests task not implemented, need nimbleutils"
