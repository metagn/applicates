import unittest, applicates

test "syntax":
  applicate double(x: SomeNumber) -> typeof(x):
    x * 2
  
  check double.apply(3) == 6

  proc foo: auto {.makeApplicate.} = x
  block:
    let x = 5
    check foo.apply() == 5
  block:
    let x = "abc"
    check foo.apply() == "abc"
  
  check "abc" |> (x !=> x[^1]) == 'c'
  check (a, 3) |> ((name, value) !=> (let name = value; name)) == 3

  makeTypedApplicate:
    template useIt =
      check it == realIt

  let realIt = 5
  block:
    let it = realIt
    useIt.apply()

test "map test":
  proc map[T](s: seq[T], f: ApplicateArg): seq[typeof(f.apply(s[0]))] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f.apply(s[i])

  check @[1, 2, 3, 4, 5].map(applicate(x) do: x - 1) == @[0, 1, 2, 3, 4]
  applicate double(x): x * 2
  check @[1, 2, 3, 4, 5].map(double) == @[2, 4, 6, 8, 10]

test "operators":
  proc map[T](s: seq[T], f: ApplicateArg): seq[typeof(f.apply(s[0]))] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f.apply(s[i])

  check @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]

  proc filter[T](s: seq[T], f: ApplicateArg): seq[T] =
    for i in 0..<s.len:
      if s[i] |> f:
        result.add(s[i])
  
  check @[1, 2, 3, 4, 5].filter(x !=> bool(x and 1)) == @[1, 3, 5]

test "cfor":
  iterator cfor(a, b, c: static Applicate): tuple[] = # ApplicateArg doesnt work here
    apply a
    while apply b:
      yield ()
      apply c

  var i = 0
  for x in cfor(() {.dirty.} !=> (var i = 0;), !=> (i < 5), !=> (inc i)):
    inc i
  check i == 5

import options

test "option unwrap":
  template unwrap[T](o: Option[T], someCb, noneCb: Applicate) =
    if o.isSome:
      let t {.used.} = o.unsafeGet
      someCb.apply(t)
    else:
      noneCb.apply()

  let a = some(3)
  let b = none(string)

  var aCorrect = false
  a.unwrap(
    applicate(n is int) do:
      aCorrect = true
      check(n == 3),
    applicate do:
      aCorrect = false)
  check aCorrect

  var bCorrect = false
  b.unwrap(
    applicate(_) do:
      bCorrect = false,
    applicate do:
      bCorrect = true)
  check bCorrect
