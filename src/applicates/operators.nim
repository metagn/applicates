import ../applicates, macros

template `==>`*(params, body): untyped =
  ## infix version of `applicate`, same parameter syntax
  runnableExamples:
    import ../applicates
    doAssert (x ==> x + 1).apply(2) == 3
    const foo = (a, b) ==> a + b
    doAssert foo.apply(1, 2) == 3
  applicate(params, body)

template `==>`*(body): untyped =
  ## same as ``applicate(body)``
  applicate(body)

template `()`*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## Call operator alias for `apply`. Must turn on experimental Nim feature
  ## `callOperator` to use. Note that this experimental feature seems to be
  ## fairly broken. This definition might also go away if Nim starts to error
  ## on templates named to overload experimental operators (which it currently
  ## doesn't inconsistently with other routines), as a `compiles` check does
  ## not work with the `experimental` pragma in other modules.
  ## 
  ## It's hard to conditionally define routines based on experimental features.
  ## Nim currently does not error with experimental operator overloads if they
  ## are templates, so this specific routine works. However if you run into
  ## problems with the call operator, `import except` should do the trick.
  appl.apply(args)

proc insertApply*(call: NimNode): NimNode =
  ## turns a regular call node into an `apply` call
  result = newNimNode(if call.kind == nnkCommand: nnkCommand else: nnkCall, call)
  result.add(bindSym"apply")
  case call.kind
  of nnkDotExpr:
    result.add(call[1], call[0])
  of nnkCall, nnkCommand:
    if call[0].kind == nnkDotExpr:
      result.add(call[0][1], call[0][0])
    else:
      result.add(call[0])
    for i in 1..<call.len:
      result.add(call[i])
  else:
    result.add(call)

macro `\`*(call: untyped): untyped =
  ## converts a call expression to an applicate call expression
  ## 
  ## supports dot calls, if the given expression is not a dot expression
  ## or call or command then it will simply apply it with no arguments
  runnableExamples:
    const foo = x ==> x + 1
    doAssert \foo(1) == 2
    doAssert \1.foo == 2
    const bar = (a, b) ==> a + b
    doAssert \bar(1, 2) == 3
    doAssert \1.bar(2) == 3
    const baz = ==> 10
    doAssert \baz() == 10
    doAssert \baz == 10
  result = insertApply(call)

proc pipeIntoCall*(value, call: NimNode): NimNode =
  ## inserts value as first argument of `call`
  case call.kind
  of nnkCall, nnkCommand:
    result = copy(call)
    result.insert(1, value)
  else:
    result = newCall(call, value)

macro `|>`*(value, call): untyped =
  ## inserts value as first argument of call, and converts it to applicate call expression
  ## 
  ## if call is a dot call, it is not modified, so value becomes the second argument in the call
  runnableExamples:
    import ../applicates

    const incr = fromSymbol(system.succ)
    const multiply = fromSymbol(`*`)
    const divide = fromSymbol(`/`)

    let foo = 3 |>
      multiply(2) |>
      incr |>
      14.divide
    doAssert foo == 2
  result = insertApply(pipeIntoCall(value, call))

macro `\>`*(value, call): untyped =
  ## same as `|>` except allows multiple arguments for `value` in the form of ``(a, b)``
  runnableExamples:
    import ../applicates

    const incr = fromSymbol(system.succ)
    const multiply = fromSymbol(`*`)
    const divide = fromSymbol(`/`)

    let foo = 3 |>
      multiply(2) |>
      incr |>
      14.divide
    doAssert foo == 2
  result = call
  if value.kind in {nnkPar, nnkTupleConstr}:
    for arg in value:
      result = pipeIntoCall(arg, result)
  else:
    result = pipeIntoCall(value, result)
  result = insertApply(result)

macro chain*(initial, calls): untyped =
  ## statement list chained version of `|>`
  runnableExamples:
    import ../applicates
    
    const incr = fromSymbol(system.succ)
    const multiply = fromSymbol(`*`)
    const divide = fromSymbol(`/`)

    let foo = chain 3:
      multiply 2
      incr
      14.divide
    doAssert foo == 2
    
  result = initial
  for call in calls:
    result = insertApply(pipeIntoCall(result, call))
