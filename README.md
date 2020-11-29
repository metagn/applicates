# applicates

"pointers" to cached AST that instantiate routines when called. caches nodes of anonymous routine definitions then gives their pointer (index in the cache) which you can pass around as a compile time argument and invoke. not a clean solution but should do the job

```nim
import applicates

proc map[T](s: seq[T], f: Applicate): seq[T] =
  result.newSeq(s.len)
  for i in 0..<s.len:
    result[i] =
      f.apply(s[i]) # maybe a little long
      # or
      (s[i]) |> f # ugly, also you need to do tuples like ((1, 2)) |> f to support multiple arguments
      # or, if --experimental:callOperator is turned on (even though this feature seems to be fairly broken)
      f(s[i])

doAssert @[1, 2, 3, 4, 5].map(applicate(x) do: x - 1) == @[0, 1, 2, 3, 4]
# alternate syntax (doesnt look great but i cant think of anything better):
doAssert @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]
```

i don't have very extensive tests for this, i might add as more use cases come up.

1 limitation is you can't type check these. you might think of a way with concepts but it's probably going to be way too complex to work
