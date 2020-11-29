# this test might break in the future with macrocache as it might not be possible to modify items

import unittest, applicates, macros

macro overload(ap: ApplicateArg, cond, body: untyped) =
  let branch = newTree(nnkElifBranch, cond, body)
  let procBody = ap.node[^1]
  if procBody.kind == nnkEmpty:
    ap.node[^1] = newStmtList(newTree(nnkWhenStmt, branch))
  elif procBody[0][^1].kind == nnkElse:
    procBody[0].insert(procBody[0].len - 2, branch)
  else:
    procBody[0].add(branch)

macro overload(ap: ApplicateArg, body: untyped) =
  let branch = newTree(nnkElse, body)
  let procBody = ap.node[^1]
  if procBody.kind == nnkEmpty:
    ap.node[^1] = newStmtList(newTree(nnkWhenStmt, branch))
  else:
    procBody[0].add(branch)

test "overload works":
  proc foo(x: static int): string {.makeApplicate.}

  overload(foo, x == 1):
    "one"
  
  overload(foo, x == 2):
    "two"
  
  overload(foo):
    "unknown"
  
  overload(foo, x mod 3 == 0):
    "some multiple of 3"
  
  check foo.apply(1) == "one"
  check foo.apply(2) == "two"
  check foo.apply(3) == "some multiple of 3"
  check foo.apply(6) == "some multiple of 3"
  check foo.apply(9) == "some multiple of 3"
  check foo.apply(43) == "unknown"
  