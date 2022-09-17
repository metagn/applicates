when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import applicates

type
  Iterator[T] = distinct Applicate
  Aggregator = distinct Applicate
  Transform[T, U] = distinct Applicate

template apply(x: static Iterator, args: varargs[untyped]): untyped = apply(Applicate(x), args)
template apply(x: static Aggregator, args: varargs[untyped]): untyped = apply(Applicate(x), args)
template apply(x: static Transform, args: varargs[untyped]): untyped = apply(Applicate(x), args)

template iter(iter: untyped): Iterator =
  type T = typeof(for x in iter: x)
  Iterator[T]:
    applicate do (agg: static Aggregator):
      for x in iter:
        agg.apply(x)

template filter[T](iter: static Iterator[T], f: static Transform[T, bool]): Iterator[T] =
  Iterator[T]:
    applicate (agg: static Aggregator):
      iter.apply(Aggregator do: x ==> (block:
        let x1 = x
        if f.apply(x1):
          agg.apply(x1)))

template map[T, U](iter: static Iterator[T], f: static Transform[T, U]): Iterator[U] =
  Iterator[U]:
    applicate (agg: static Aggregator):
      iter.apply(Aggregator do: x ==> agg.apply(f.apply(x)))

template use[T, U](iter: static Iterator[T], f: static Transform[T, U]): untyped =
  iter.apply(Aggregator do: x ==> f.apply(x))

test "filter map use":
  var s: seq[int]
  use(
    map(
      filter(
        iter(-7..11),
        Transform[int, bool](x ==> x mod 3 == 0)),
      Transform[int, int](x ==> x + 2)),
    Transform[int, void](x ==> s.add(x)))
  check s == @[-4, -1, 2, 5, 8, 11]
  var s2: seq[int]
  (-7..11).
    iter.
    filter(Transform[int, bool](x ==> x mod 3 == 0)).
    map(Transform[int, int](x ==> x + 2)).
    use(Transform[int, void](x ==> s2.add(x)))
  check s2 == s

import macros

macro iterate(init, st): untyped =
  result = newCall(bindSym"iter", init)
  for s in st:
    if s.kind == nnkIdent:
      result = newCall(s, result)
    else:
      result = newCall(s[0], result)
      for i in 1..<s.len:
        result.add(s[i])

test "iterate":
  var s: seq[int]
  iterate -7..11:
    filter(Transform[int, bool] do: x ==> x mod 3 == 0)
    map(Transform[int, int] do: x ==> x + 2)
    filter(Transform[int, bool] do: x ==> x > 0)
    use(Transform[int, void] do: x ==> s.add(x))
  check s == @[2, 5, 8, 11]

template collect[T](iter: static Iterator[T]): seq[T] =
  var s: seq[T]
  iter.apply(Aggregator do: x ==> s.add(x))
  s

template enumerate[T](iter: static Iterator[T]): Iterator[(int, T)] =
  Iterator[(int, T)]:
    applicate (agg: static Aggregator):
      var i = 0
      iter.apply Aggregator do:
        applicate x:
          agg.apply((i, x))
          inc i

from algorithm import reversed

test "collect and fold":
  let s = iterate -7..11:
    filter(Transform[int, bool] do: x ==> x mod 3 == 0)
    map(Transform[int, int] do: x ==> x + 2)
    enumerate
    filter(Transform[(int, int), bool] do: x ==> x[1] > 0)
    map(Transform[(int, int), (int, string)] do: x ==> (x[0], $x[1]))
    enumerate
    collect
  check s == @[(0, (2, "2")), (1, (3, "5")), (2, (4, "8")), (3, (5, "11"))]
  
  template fold[T, U](iter: static Iterator[T], init: U, op: static Transform[(U, T), U]): U =
    var a = init
    iter.apply(Aggregator do: x ==> (a = op.apply((a, x))))
    a

  let s2 = iterate reversed(s):
    map(Transform[(int, (int, string)), string] do: x ==> x[1][1])
    fold("", Transform[(string, string), string] do: x ==> x[0] & x[1])
  check s2 == "11852"

test "iterator":
  iterator foo(x: Slice[int]): auto = # iterator cannot be generic for some reason
    iterate x:
      filter(Transform[int, bool] do: x ==> x mod 3 == 0)
      map(Transform[int, int] do: x ==> x + 2)
      use(Transform[int, void] do: x ==> (;yield x))
  
  var s: seq[int]
  for x in foo(-7..11):
    s.add(x)
  check s == @[-4, -1, 2, 5, 8, 11]
