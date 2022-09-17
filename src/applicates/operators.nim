import ../applicates, macros

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
    import ../applicates
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

    const incr = toApplicate(system.succ)
    const multiply = toApplicate(`*`)
    const divide = toApplicate(`/`)

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

    const incr = toApplicate(system.succ)
    const multiply = toApplicate(`*`)
    const divide = toApplicate(`/`)

    let foo = (3, 2) \>
      multiply \>
      incr \>
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
    
    const incr = toApplicate(system.succ)
    const multiply = toApplicate(`*`)
    const divide = toApplicate(`/`)

    let foo = chain 3:
      multiply 2
      incr
      14.divide
    doAssert foo == 2
    
  result = initial
  for call in calls:
    result = insertApply(pipeIntoCall(result, call))
