# applicates

instantiated "pointers" to cached AST. caches nodes of anonymous routine definitions OR symbols then returns their pointer (index/key in the cache) which you can pass around as a compile time argument and instantiate in order to use. this allows for fully inlined lambdas via *"anonymous templates"*, which is the construct that the macros in this library mainly focus on.

Would have preferred not using a cache to do this, but for now it should do the job.

```nim
import applicates
# optional operators:
import applicates/operators

proc map[T](s: seq[T], f: ApplicateArg): seq[T] =
  result.newSeq(s.len)
  for i in 0..<s.len:
    let x = s[i]
    result[i] = f.apply(x)
    # optional operators (couldnt decide on anything):
    result[i] = f | x
    result[i] = x |< f # accepts multiple arguments like (1, 2) |< f
    result[i] = x |> f # does not do above, and injects x into right hand side
    result[i] = \f(x)
    result[i] = \x.f
    result[i] = f(x) # when experimental callOperator is enabled
    result[i] = x.f # ditto

# `applicate do` here generates an anonymous template, so `x - 1` is inlined at AST level:
doAssert @[1, 2, 3, 4, 5].map(applicate do (x): x - 1) == @[0, 1, 2, 3, 4]
doAssert @[1, 2, 3, 4, 5].map(fromSymbol(succ)) == @[2, 3, 4, 5, 6]
# optional operators:
doAssert @[1, 2, 3, 4, 5].map(x !=> x * 2) == @[2, 4, 6, 8, 10]
doAssert @[1, 2, 3, 4, 5].map(x \=> x * 2) == @[2, 4, 6, 8, 10]
```

See tests for more example uses of this library. Tests are ran for multiple backends.

Note: Since `Applicate` is implemented as `distinct ApplicateKey` and is also usually used as `static Applicate` (for which `ApplicateArg` is an alias), this library fairly pushes Nim's type system, so annotating applicates with types can be difficult. Nim macro errors in general are also not great.
