import unittest, applicates, strutils

test "makeapplicate":
  proc foo: auto {.makeApplicate.} = x
  block:
    let x = 5
    check foo.apply() == 5
  block:
    let x = "abc"
    check foo.apply() == "abc"

  makeTypedApplicate:
    template useIt =
      check it == realIt

  let realIt = 5
  block:
    let it = realIt
    useIt.apply()
  
  const incr = makeTypedApplicate do (x: int) -> int: x + 1
  doAssert incr.apply(5) == 6
  const capitalize = makeTypedApplicate proc(x: string): string =
    result = x
    result[0] = toUpperAscii result[0]
  doAssert capitalize.apply("hello") == "Hello"
  const joiner = makeTypedApplicate do (x: openarray[string], s: string = ", ") -> string:
    result = strutils.join(x, s)
  doAssert joiner.apply(["a", "b", "c"], ".") == "a.b.c"

test "applicate macro and apply":
  applicate double(x: SomeNumber) -> typeof(x):
    x * 2
  
  check double.apply(3) == 6

  const foo = applicate do (num: int, name):
    type `name` = object
      field: int
    var x {.inject.}: `name`
    x.field = num
  
  foo.apply(5, FooType)
  check x.field == 5
    
  const incr = applicate do (x: int) -> int: x + 1
  doAssert incr.apply(x.field) == 6

  applicate named do (a, b; c: int):
    let a = b(c)
  
  named.apply(upperA, char, 65)
  doAssert upperA == 'A'
  
test "operators":
  check (x !=> x[^1]) | "abc" == 'c'
  check \((name, value) \=> (let name = value; name))(a, 3) == 3

test "map test":
  proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f.apply(s[i])

  check @[1, 2, 3, 4, 5].map(applicate(x) do: x - 1) == @[0, 1, 2, 3, 4]
  check @[1, 2, 3, 4, 5].map(applicate do (x): x - 1) == @[0, 1, 2, 3, 4]
  applicate double(x): x * 2
  check @[1, 2, 3, 4, 5].map(double) == @[2, 4, 6, 8, 10]

  iterator map[T](s: T, f: ApplicateArg): auto =
    for x in s:
      yield f.apply(x)
  
  var s: seq[float]
  for y in @[1, 2, 3, 4, 5].map(x \=> x / 7):
    s.add(y)
  check s == @[1/7, 2/7, 3/7, 4/7, 5/7]

test "toUntyped":
  const adder = toUntyped(`+`, 2)
  const toString = toUntyped(`$`)
  check (2, 3) |< adder |< toString == "5"
