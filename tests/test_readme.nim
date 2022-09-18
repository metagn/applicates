import applicates

# `ApplicateArg` is `static Applicate`
proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
  result.newSeq(s.len)
  for i in 0..<s.len:
    let x = s[i]
    result[i] = f.apply(x) # inlined at AST level

doAssert @[1, 2, 3, 4, 5].map(applicate do (x: int) -> int: x - 1) == @[0, 1, 2, 3, 4]
doAssert @[1, 2, 3, 4, 5].map(toApplicate(succ)) == @[2, 3, 4, 5, 6]
const double = x ==> x * 2
doAssert @[1, 2, 3, 4, 5].map(double) == @[2, 4, 6, 8, 10]
