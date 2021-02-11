# applicates

instantiated "pointers" to cached AST. caches nodes of anonymous routine definitions OR symbols then returns their pointer (index/key in the cache) which you can pass around as a compile time argument and instantiate in order to use. this allows for fully inlined lambdas via *"anonymous templates"*, which is the construct that the macros in this library mainly focus on.

Would have preferred not using a cache to do this, but for now it should do the job.

```nim
import applicates

proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
  result.newSeq(s.len)
  for i in 0..<s.len:
    let x = s[i]
    result[i] = f.apply(x)
    # supported sugar for the above (best I could come up with, might be too much):
    result[i] = f | x
    result[i] = x |< f
    result[i] = \f(x)
    result[i] = \x.f
    result[i] = f(x) # when experimental callOperator is enabled
    result[i] = x.f # ditto

# `applicate do` here generates an anonymous template, so `x - 1` is inlined at AST level:
doAssert @[1, 2, 3, 4, 5].map(applicate do (x): x - 1) == @[0, 1, 2, 3, 4]
doAssert @[1, 2, 3, 4, 5].map(fromSymbol(succ)) == @[2, 3, 4, 5, 6]
# sugar for `applicate do` syntax (again, best I could come up with):
doAssert @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]
doAssert @[1, 2, 3, 4, 5].map(x \=> x * 2) == @[2, 4, 6, 8, 10]
```

See tests for more example uses of this library. Tests are ran and docs are built with [nimbleutils](https://github.com/hlaaftana/nimbleutils).

Note: Since `Applicate` is implemented as `distinct int` or `distinct string` and is also usually used as `static Applicate` (for which `ApplicateArg` is an alias), you might have a fair bit of trouble/bugs with the type system. This is unfortunate as it limits the possibilities for type annotated functional programming using applicates. The messiness of Nim's error system when dealing with macros also does not help in this regard.
