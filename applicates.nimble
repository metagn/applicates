# Package

version       = "0.3.0"
author        = "metagn"
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
    buildDocs(gitUrl = "https://github.com/metagn/applicates")
  else:
    echo "docs task not implemented, need nimbleutils"

task tests, "run tests for multiple backends and defines":
  when declared(runTests):
    runTests(
      backends = {c, #[js]#}, 
      #optionCombos = @["", "-d:applicatesUseMacroCache", "-d:applicatesCacheUseTable"]
    )
  else:
    echo "tests task not implemented, need nimbleutils"
