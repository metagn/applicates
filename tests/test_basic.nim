import unittest, applates

test "map test":
  proc map[T](s: seq[T], f: Applate): seq[T] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f.apply(s[i])

  check @[1, 2, 3, 4, 5].map(applate(x) do: x - 1) == @[0, 1, 2, 3, 4]
  applate double(x): x * 2
  check @[1, 2, 3, 4, 5].map(double) == @[2, 4, 6, 8, 10]

test "operators":
  proc map[T](s: seq[T], f: Applate): seq[T] =
    result.newSeq(s.len)
    for i in 0..<s.len:
      result[i] = f ! (s[i])

  check @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]

  proc filter[T](s: seq[T], f: Applate): seq[T] =
    for i in 0..<s.len:
      if s[i] |> f:
        result.add(s[i])
  
  check @[1, 2, 3, 4, 5].filter(x !=> bool(x and 1)) == @[1, 3, 5]

test "cfor":
  iterator cfor(a, b, c: static ApplateId): tuple[] = # Applate doesnt work here
    apply a
    while apply b:
      yield ()
      apply c

  var i = 0
  for x in cfor(() {.dirty.} !=> (var i = 0;), !=> (i < 5), !=> (inc i)):
    inc i
  check i == 5
