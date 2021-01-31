# Package

version       = "0.2.0"
author        = "hlaaftana"
description   = "instantiated \"pointers\" to cached AST"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.20.0"

import os

task docs, "build docs":
  const
    gitUrl = "https://github.com/hlaaftana/applicates"
    gitCommit = "master"
    gitDevel = "master" 
  for f in walkDirRec("src"):
    exec "nim doc --git.url:" & gitUrl &
      " --git.commit:" & gitCommit &
      " --git.devel:" & gitDevel &
      " --outdir:docs " & f

task tests, "runs tests with all define variations":
  echo "testing normally"
  exec "nimble test"
  echo "testing with macro cache"
  exec "nimble test -d:applicatesUseMacroCache"
  echo "testing with table cache"
  exec "nimble test -d:applicatesCacheUseTable"
