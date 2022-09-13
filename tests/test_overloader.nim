when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import applicates, macros, macrocache

type Overloadable = object
  appl: Applicate
  overloads: CacheSeq
  # really pushing it with the cache

macro overload(c: static Overloadable, cond, body: untyped) =
  c.overloads.add(newTree(nnkElifBranch, cond, body))
macro overload(c: static Overloadable, body: untyped) =
  c.overloads.add(newTree(nnkElse, body))

macro overloadable(body) =
  let tempNameStr = repr genSym(nskConst, "temp")
  let tempName = ident tempNameStr
  let body = copy body
  let oldName = body[0]
  body[0] = tempName
  if body[^1].kind == nnkEmpty: body[^1] = newStmtList()
  body[^1].add(quote do:
    macro loadOverloads(): untyped =
      result = newTree(nnkWhenStmt)
      for o in CacheSeq("overloads." & `tempNameStr`):
        let o = copy o
        if result.len > 0 and result[^1].kind == nnkElse:
          result.insert(result.len - 1, o)
        else:
          result.add(o)
    loadOverloads())
  result = quote do:
    makeApplicate(`body`)
    const `oldName` = Overloadable(appl: `tempName`,
      overloads: CacheSeq("overloads." & `tempNameStr`))

template apply(c: static Overloadable, args: varargs[untyped]): untyped =
  c.appl.apply(args)

test "overload works":
  proc foo(x: static int): string {.overloadable.}

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
  