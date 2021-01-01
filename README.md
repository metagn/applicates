# applicates

"pointers" to cached AST that instantiate routines when called. caches nodes of anonymous routine definitions then gives their pointer (index in the cache) which you can pass around as a compile time argument and invoke. not a clean solution but should do the job

```nim
import applicates

proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
  result.newSeq(s.len)
  for i in 0..<s.len:
    result[i] =
      f.apply(s[i]) # maybe a little long
      # or
      f | s[i]
      s[i] |< f # noisy, also you need to do tuples like ((1, 2)) |< f as (1, 2) |< f becomes f.apply(1, 2)
      # or
      f(s[i]) # uses experimental callOperator feature, if it breaks your code use `import except`

doAssert @[1, 2, 3, 4, 5].map(applicate do (x): x - 1) == @[0, 1, 2, 3, 4]
# alternate syntax (doesnt look great but i cant think of anything better):
doAssert @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]
```

tests show some of the possibilities with this construct

1 limitation is you can't really annotate these with types. you might think of a way with concepts but it's probably going to be way too complex to work
