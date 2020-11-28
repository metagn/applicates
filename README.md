# applates

applied templates. caches nodes of anonymous template definitions then stores their ID (index in the cache) which you can pass around as a static argument and invoke. not a clean solution but should do the job

```nim
import applates

proc map[T](s: seq[T], f: Applate): seq[T] =
  # this is a proc, applates instantiated inside foreign procs will not be able
  # to access local symbols, just a heads up
  result.newSeq(s.len)
  for i in 0..<s.len:
    result[i] =
      f.apply(s[i]) # maybe a little long
      # or
      f!(s[i]) # this does not have great precedence
      # or
      (s[i]) |> f # ugly, also you need to do tuples like ((1, 2)) |> f to support multiple arguments

doAssert @[1, 2, 3, 4, 5].map(applate(x) do: x - 1) == @[0, 1, 2, 3, 4]
# alternate syntax (doesnt look great but i cant think of anything better):
doAssert @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]
```

1 limitation is you can't type check these. you might think of a way with concepts but it's probably going to be way too complex to work
