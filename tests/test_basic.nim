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
  proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f.apply(s[i])

  check @[1, 2, 3, 4, 5].map(applicate(x) do: x - 1) == @[0, 1, 2, 3, 4]
  applicate double(x): x * 2
  check @[1, 2, 3, 4, 5].map(double) == @[2, 4, 6, 8, 10]

test "applying":
  template iterCollectSeq(iter: untyped): untyped =
    var s: seq[typeof(iter, typeOfIter)]
    for x in iter:
      s.add(x)
    s
  
  iterator map[T](s: seq[T], f: ApplicateArg): auto =
    for x in s:
      yield f.apply(x)

  check iterCollectSeq(@[1, 2, 3, 4, 5].map(x !=> x * 2)) == @[2, 4, 6, 8, 10]

  iterator filter[T](s: seq[T], f: ApplicateArg): auto =
    for x in s:
      if x |> f:
        yield x
  
  check iterCollectSeq(@[1, 2, 3, 4, 5].filter(x !=> bool(x and 1))) == @[1, 3, 5]

test "cfor":
  iterator cfor(a, b, c: static Applicate): tuple[] =
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
  proc unwrap[T](o: Option[T], someCb, noneCb: static Applicate): auto =
    if o.isSome:
      \someCb(o.unsafeGet)
    else:
      \noneCb

  let a = some(3)
  let b = none(string)

  check a.unwrap(
    (n: int) !=> (check(n == 3); true),
    !=> false)

  check b.unwrap(
    _ !=> false,
    !=> true)
