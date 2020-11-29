# Package

version       = "0.0.0" # unreleased
author        = "hlaaftana"
description   = "\"pointers\" to cached AST that instantiate routines when called"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 0.20.0"

import os

task docs, "build docs":
  for f in walkDirRec("src"):
    exec "nim doc --git.url:https://github.com/hlaaftana/applicates --git.commit:master --git.devel:master " &
      "--outdir:docs " & f

task tests, "runs tests with all define variations":
  echo "testing normally"
  exec "nimble test"
  echo "testing with macro cache"
  exec "nimble test -d:applicatesUseMacroCache"