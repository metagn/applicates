import unittest, applicates

applicate iter(iter: untyped):
  applicate (agg: static Applicate):
    for x in iter:
      agg.apply(x)

applicate filter(iter: static Applicate, f: static Applicate):
  applicate (agg: static Applicate):
    iter.apply(x \=> (block:
      let x1 = x
      if f.apply(x1):
        agg.apply(x1)))

applicate map(iter: static Applicate, f: static Applicate):
  applicate (agg: static Applicate):
    iter.apply(x \=> agg.apply(f.apply(x)))

applicate use(iter: static Applicate, f: static Applicate):
  iter.apply(x \=> f.apply(x))

test "filter map use":
  var s: seq[int]
  use.apply(map.apply(filter.apply(iter.apply(-7..11), x \=> x mod 3 == 0), x \=> x + 2), x \=> s.add(x))
  check s == @[-4, -1, 2, 5, 8, 11]
  var s2: seq[int]
  (
    (
      (
        (-7..11) |< iter,
        x \=> x mod 3 == 0
      ) |< filter,
      x \=> x + 2
    ) |< map,
    x \=> s2.add(x)
  ) |< use
  check s2 == s

import macros

macro iterate(init, st): untyped =
  result = newCall(bindSym"iter", init)
  for s in st:
    if s.kind == nnkIdent:
      result = newCall(bindSym"apply", s, result)
    else:
      result = newCall(bindSym"apply", s[0], result)
      for i in 1..<s.len:
        result.add(s[i])

test "iterate":
  var s: seq[int]
  iterate -7..11:
    filter(x \=> x mod 3 == 0)
    map(x \=> x + 2)
    filter(x \=> x > 0)
    use(x \=> s.add(x))
  check s == @[2, 5, 8, 11]

applicate collect(iter: static Applicate):
  var elemType {.compileTime.}: NimNode
  macro storeElemType(ty: typed) {.gensym.} =
    result = newEmptyNode()
    elemType = ty
  if false:
    iter.apply(x \=> storeElemType(typeof(x)))
  macro getElemType(): untyped {.gensym.} =
    result = elemType
  var s: seq[getElemType()]
  iter.apply(x \=> s.add(x))
  s

applicate enumerate(iter: static Applicate):
  applicate (agg: static Applicate):
    var i = 0
    iter.apply:
      applicate x:
        agg.apply((i, x))
        inc i

from algorithm import reversed

test "collect and fold":
  let s = iterate -7..11:
    filter(x \=> x mod 3 == 0)
    map(x \=> x + 2)
    enumerate
    filter(x \=> x[1] > 0)
    map(x \=> (x[0], $x[1]))
    enumerate
    collect
  check s == @[(0, (2, "2")), (1, (3, "5")), (2, (4, "8")), (3, (5, "11"))]
  
  applicate fold(iter: static Applicate, init: untyped, op: static Applicate):
    var a = init
    iter.apply(x \=> (a = op.apply((a, x))))
    a

  let s2 = iterate reversed(s):
    map(x \=> x[1][1])
    fold("", x \=> x[0] & x[1])
  check s2 == "11852"

test "yield":
  iterator foo[T](x: T): auto =
    iterate x:
      filter(x \=> x mod 3 == 0)
      map(x \=> x + 2)
      use:
        \=> x:
          yield x
  
  var s: seq[int]
  for x in foo(-7..11):
    s.add(x)
  check s == @[-4, -1, 2, 5, 8, 11]
