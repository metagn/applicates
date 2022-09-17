when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import applicates, applicates/operators

applicate iter(iter: untyped):
  applicate (agg: static Applicate):
    for x in iter:
      agg.apply(x)

applicate filter(iter: static Applicate, f: static Applicate):
  applicate (agg: static Applicate):
    iter.apply(applicate do (x): (block:
      let x1 = x
      if f.apply(x1):
        agg.apply(x1)))

applicate map(iter: static Applicate, f: static Applicate):
  applicate (agg: static Applicate):
    iter.apply(applicate do (x): agg.apply(f.apply(x)))

applicate use(iter: static Applicate, f: static Applicate):
  iter.apply(applicate do (x): f.apply(x))

test "filter map use":
  var s: seq[int]
  use.apply(map.apply(filter.apply(iter.apply(-7..11), applicate do (x): x mod 3 == 0), applicate do (x): x + 2), applicate do (x): s.add(x))
  check s == @[-4, -1, 2, 5, 8, 11]
  var s2: seq[int]
  (-7..11) |>
    iter |>
    filter(applicate do (x): x mod 3 == 0) |>
    map(applicate do (x): x + 2) |>
    use(applicate do (x): s2.add(x))
  check s2 == s

import macros

template iterate(init, st): untyped =
  chain(iter.apply(init), st)

test "iterate":
  var s: seq[int]
  iterate -7..11:
    filter(applicate do (x): x mod 3 == 0)
    map(applicate do (x): x + 2)
    filter(applicate do (x): x > 0)
    use(applicate do (x): s.add(x))
  check s == @[2, 5, 8, 11]

applicate collect(iter: static Applicate):
  var elemType {.compileTime.}: NimNode
  macro storeElemType(ty: typed) {.gensym.} =
    result = newEmptyNode()
    elemType = ty
  if false:
    iter.apply(applicate do (x): storeElemType(typeof(x)))
  macro getElemType(): untyped {.gensym.} =
    result = elemType
  var s: seq[getElemType()]
  iter.apply(applicate do (x): s.add(x))
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
    filter(applicate do (x): x mod 3 == 0)
    map(applicate do (x): x + 2)
    enumerate
    filter(applicate do (x): x[1] > 0)
    map(applicate do (x): (x[0], $x[1]))
    enumerate
    collect
  check s == @[(0, (2, "2")), (1, (3, "5")), (2, (4, "8")), (3, (5, "11"))]
  
  applicate fold(iter: static Applicate, init: untyped, op: static Applicate):
    var a = init
    iter.apply(applicate do (x): (a = op.apply((a, x))))
    a

  let s2 = iterate reversed(s):
    map(applicate do (x): x[1][1])
    fold("", applicate do (x): x[0] & x[1])
  check s2 == "11852"

test "yield":
  iterator foo[T](x: T): auto =
    iterate x:
      filter(applicate do (x): x mod 3 == 0)
      map(applicate do (x): x + 2)
      use(applicate do (x): yield x)
  
  var s: seq[int]
  for x in foo(-7..11):
    s.add(x)
  check s == @[-4, -1, 2, 5, 8, 11]
