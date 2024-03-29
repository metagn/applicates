# Package

version       = "0.4.0"
author        = "metagn"
description   = "generalized routine and symbol pointers"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.20.0"

when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

task docs, "build docs for all modules":
  when declared(buildDocs):
    buildDocs(gitUrl = "https://github.com/metagn/applicates")
  else:
    echo "docs task not implemented, need nimbleutils"

task tests, "run tests for multiple backends and defines":
  when declared(runTests):
    runTests(
      backends = {c, nims}, 
      optionCombos = @[
        "",
        "-d:applicatesCacheUseTable"]
    )
  else:
    echo "tests task not implemented, need nimbleutils"
