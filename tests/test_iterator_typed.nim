import unittest, applicates, macros

type Iterator = distinct Applicate

template apply(iter: Iterator, value: untyped): untyped = apply(static(Applicate(iter)), value)
template propagate(iter: Iterator, value: untyped): untyped = apply(static(Applicate(iter)), value)

macro itr(args: varargs[untyped]): untyped =
  let applCall = newCall("applicate")
  for a in args: applCall.add(a)
  result = newCall(bindSym"Iterator", applCall)

const iter = applicate do (iter: untyped) -> Iterator: # iter here is Iterable
  itr do (agg: static Applicate):
    for x in iter:
      agg.apply(x)

const filter = applicate do (iter: static Iterator, f: static Applicate) -> Iterator:
  itr do (agg: static Applicate):
    iter.propagate(x \=> (block:
      let x1 = x
      if f.apply(x1):
        agg.apply(x1)))

const map = applicate do (iter: static Iterator, f: static Applicate) -> Iterator:
  itr do (agg: static Applicate):
    iter.propagate(x \=> agg.apply(f.apply(x)))

const each = applicate do (iter: static Iterator, f: static Applicate):
  iter.propagate(f)

test "single map":
  var s: seq[int]
  map.apply(iter.apply(0..4), x \=> x + 1).propagate(x \=> s.add(x))
  check s == @[1, 2, 3, 4, 5]

test "filter map use":
  var s: seq[int]
  const goo = map.apply(filter.apply(iter.apply(-7..11), x \=> x mod 3 == 0), x \=> x + 2)
  goo.apply(x \=> s.add(x))
  check s == @[-4, -1, 2, 5, 8, 11]
  var s2: seq[int]
  ((
    (
      (-7..11) |< iter,
      x \=> x mod 3 == 0
    ) |< filter,
    x \=> x + 2
  ) |< map).propagate(x \=> s2.add(x))
  check s2 == s

import macros

macro iterate(init, st): untyped =
  st.insert(0, bindSym"iter")
  result = getAst(chain(init, st))

test "iterate":
  var s: seq[int]
  iterate -7..11:
    filter(x \=> x mod 3 == 0)
    map(x \=> x + 2)
    filter(x \=> x > 0)
    each(x \=> s.add(x))
  check s == @[2, 5, 8, 11]

const collect = applicate do (iter: static Iterator):
  var elemType {.compileTime.}: NimNode
  macro storeElemType(ty: typed) {.gensym.} =
    result = newEmptyNode()
    elemType = ty
  if false:
    iter.apply(x \=> storeElemType(typeof(x)))
  macro getElemType(): untyped {.gensym.} =
    result = elemType
  var s: seq[getElemType()]
  iter.propagate(x \=> s.add(x))
  s

const enumerate = applicate do (iter: static Iterator):
  itr do (agg: static Applicate):
    var i = 0
    iter.apply:
      applicate do (x):
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
  
  const fold = applicate do (iter: static Iterator, init: untyped, op: static Applicate):
    var a = init
    iter.propagate(x \=> (a = op.apply((a, x))))
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
      each:
        \=> x:
          yield x
  
  var s: seq[int]
  for x in foo(-7..11):
    s.add(x)
  check s == @[-4, -1, 2, 5, 8, 11]
