import macros

import applicates/internals
export ApplicateKey, Applicate, ApplicateArg

macro makeApplicate*(body): untyped =
  ## Registers given routine definitions as applicates and
  ## assigns each applicate to a constant with the name of its routine.
  runnableExamples:
    proc foo: auto {.makeApplicate.} = x
    block:
      let x = 5
      doAssert foo.apply() == 5
    block:
      let x = "abc"
      doAssert foo.apply() == "abc"
  case body.kind
  of nnkStmtList:
    result = newNimNode(nnkStmtList, body)
    for st in body: result.add(getAst(makeApplicate(st)))
  of RoutineNodes:
    let num = applicateCount()
    let b = newNimNode(
      if body.kind in {nnkDo, nnkLambda}:
        nnkProcDef
      else:
        body.kind, body)
    for n in body:
      b.add(n)
    b[0] = ident repr gensym(
      case b.kind
      of nnkTemplateDef: nskTemplate
      of nnkMacroDef: nskMacro
      of nnkProcDef: nskProc
      of nnkConverterDef: nskConverter
      of nnkIteratorDef: nskIterator
      of nnkMethodDef: nskMethod
      of nnkFuncDef: nskFunc
      else: nskTemplate, "appl" & $num)
    let key = registerApplicate(b, num)
    result = newCall(bindSym"Applicate", newLit(key))
    if body[0].kind != nnkEmpty:
      result = newConstStmt(
        if body[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
          ident repr body[0]
        else:
          body[0], result)
  else:
    error("cannot turn non-routine into applicate, given kind " & $body.kind, body)

macro makeApplicateFromTyped*(body: typed): untyped =
  ## Registers applicate with given routine(s), but forces it to be type
  ## checked first. This lets it use symbols that are accessible during the
  ## registering, but if the routine is not a template then *only* local
  ## symbols are accessible.
  ## 
  ## Works best for templates and macros, so `applicate` uses this.
  ## 
  ## **Note:** This will generate an unused warning for the given routine,
  ## `makeTypedApplicate` automatically generates a `used` pragma but only on
  ## untyped routine expressions.
  ## 
  case body.kind
  of nnkStmtList:
    result = newNimNode(nnkStmtList, body)
    for st in body: result.add(getAst(makeApplicateFromTyped(st)))
  of RoutineNodes:
    result = getAst(makeApplicate(body))
  else:
    error("cannot turn non-routine into applicate, given kind " & $body.kind, body)

macro makeTypedApplicate*(body: untyped): untyped =
  ## Calls `makeApplicateFromTyped` without giving an unused warning.
  ## 
  ## Accomplishes this by injecting {.used.}.
  runnableExamples:
    makeTypedApplicate:
      template useIt =
        doAssert it == realIt

    let realIt = 5
    block:
      let it = realIt
      useIt.apply()
  case body.kind
  of nnkStmtList:
    result = newNimNode(nnkStmtList, body)
    for st in body: result.add(getAst(makeTypedApplicate(st)))
  of RoutineNodes:
    if body[0].kind != nnkEmpty:
      if body[4].kind == nnkEmpty:
        body[4] = newTree(nnkPragma, ident"used")
      else:
        body[4].add(ident"used")
    result = getAst(makeApplicateFromTyped(body))
  else:
    error("cannot turn non-routine into applicate, given kind " & $body.kind, body)

macro applicate*(params, body): untyped =
  ## generates a template based on the params and body and registers it as a typed
  ## applicate. when anonymous, returns applicate id literal
  ## (compatible with ApplicateArg/Applicate). when a name is specified (using
  ## call/object constructor syntax), defines that name as a constant with the
  ## value being the applicate id.
  ## 
  ## param syntax: `p: T`, or `p is T` if Nim doesn't like colons,
  ## and `paramList -> T` for return type or `paramsList: T` for return
  ## type if `paramsList` is in parentheses. type annotations that are grouped
  ## together like `a, b: int` resolve to `a: int, b: int`.
  ## 
  ## the param syntax might be removed in the future given that `do` directly
  ## replicates regular routine parameters
  ## 
  ## note: the return type is untyped by default unlike templates, where it is void
  runnableExamples:
    applicate foo(name: untyped, val: int):
      let name = val
    
    foo.apply(x, 5)
    doAssert x == 5

    template double(appl: ApplicateArg) =
      appl.apply()
      appl.apply()
    
    var c = 0
    when false: # runnableExamples does not handle do: correctly, this works otherwise
      double(applicate do:
        double(applicate do:
          double(applicate do: inc c)))
    else:
      double applicate(
        double applicate(
          double applicate(inc(c))))
    doAssert c == 8
  var params = params
  var returnType = ident"untyped"
  var pragma = newEmptyNode()
  # outer pragma check
  if params.kind == nnkPragmaExpr:
    pragma = params[1]
    params = params[0]
  if params.kind == nnkExprColonExpr and params[0].kind == nnkPar:
    returnType = params[1]
    params = params[0]
  elif params.kind == nnkInfix and params[0].eqIdent"->":
    returnType = params[2]
    params = params[1]
  # inner pragma check
  if params.kind == nnkPragmaExpr:
    pragma = params[1]
    params = params[0]
  let name = if params.kind == nnkInfix and params[0].eqIdent"*":
    let val = postfix(params[0], "*")
    params = params[1]
    val
  elif params.kind in {nnkCall, nnkObjConstr}:
    let newParams = newNimNode(nnkPar, params)
    for pi in 1..<params.len:
      newParams.add(params[pi])
    let val = params[0]
    params = newParams
    if val.eqIdent"_":
      nil
    else:
      val
  else:
    nil
  if params.kind notin {nnkPar, nnkTupleConstr}:
    let oldParams = params
    params = newNimNode(nnkPar, oldParams)
    params.add(oldParams)
  let formalParams = newTree(nnkFormalParams, returnType)
  var lastIdents = 0
  for p in params:
    formalParams.add:
      case p.kind
      of nnkExprColonExpr:
        for i in (formalParams.len - lastIdents)..(formalParams.len - 1):
          formalParams[i][1] = p[1]
        lastIdents = 0
        newIdentDefs(p[0], p[1])
      of nnkIdent, nnkSym, nnkClosedSymChoice, nnkOpenSymChoice, nnkAccQuoted:
        inc lastIdents
        newIdentDefs(p, newEmptyNode())
      elif p.kind == nnkInfix and p[0].eqIdent"is":
        for i in (formalParams.len - lastIdents)..<formalParams.len:
          formalParams[i][1] = p[2]
        lastIdents = 0
        newIdentDefs(p[1], p[2])
      else:
        error("unrecognized param kind: " & $params.kind, params)
        newIdentDefs(ident"_", newEmptyNode())
  let templ = newNimNode(nnkTemplateDef, body)
  templ.add(
    # should be ident here, otherwise declared breaks
    name,
    newEmptyNode(), newEmptyNode(),
    formalParams,
    pragma,
    newEmptyNode(),
    body)
  if name.isNil:
    let temp = genSym(nskTemplate, "tempAppl")
    templ[0] = temp
    result = newStmtList(
      getAst(makeTypedApplicate(templ)),
      ident repr temp
    )
  else:
    result = getAst(makeTypedApplicate(templ))

macro applicate*(body): untyped =
  ## syntax for applicates with no parameters, or for applicates made with
  ## `do` notation
  runnableExamples:
    const defineX = applicate:
      let x {.inject.} = 3
    defineX.apply()
    doAssert x == 3

    # this is how do notation works, which we unfortunately can't show
    # as an example because runnableexamples breaks do notation:
    
    # const incr = applicate do (x: int) -> int: x + 1
    # doAssert incr.apply(x) == 4

    # named:
    
    # applicate named do (a, b; c: int):
    #   let a = b(c)
    # named.apply(upperA, char, 65)
    # doAssert upperA == 'A'
  if body.kind == nnkDo:
    let templ = newNimNode(nnkTemplateDef, body)
    for s in body:
      templ.add(s)
    if templ[3][0].kind == nnkEmpty: templ[3][0] = ident"untyped"
    result = getAst(makeTypedApplicate(templ))
  elif body.kind in {nnkCall, nnkCommand} and body.len == 2 and body[1].kind == nnkDo:
    let templ = newNimNode(nnkTemplateDef, body[1])
    for s in body[1]:
      templ.add(s)
    if templ[3][0].kind == nnkEmpty: templ[3][0] = ident"untyped"
    templ[0] = body[0]
    result = getAst(makeTypedApplicate(templ))
  else:
    let args = newPar()
    result = getAst(applicate(args, body))

template `==>`*(params, body): untyped =
  ## infix version of `applicate`, same parameter syntax
  runnableExamples:
    doAssert (x ==> x + 1).apply(2) == 3
    const foo = (a, b) ==> a + b
    doAssert foo.apply(1, 2) == 3
  applicate(params, body)

template `==>`*(body): untyped =
  ## same as ``applicate(body)``
  applicate(body)

macro toApplicate*(sym: untyped): Applicate =
  ## directly registers `sym` as an applicate node. might be more efficient
  ## than `toCallerApplicate` for most cases, and accepts varying arities
  runnableExamples:
    const plus = toApplicate(`+`)
    doAssert plus.apply(1, 2) == 3
  let key = registerApplicate(sym)
  result = newCall(bindSym"Applicate", newLit(key))

template `&&`*(sym): untyped =
  ## same as ``toApplicate(sym)``
  runnableExamples:
    const foo = &&min
    doAssert foo.apply(1, 2) == 1
  toApplicate(sym)

macro toCallerApplicate*(sym: untyped, arity: static int): Applicate =
  ## creates an applicate of a template with `n` = `arity` untyped parameters
  ## that calls the given symbol `sym`
  runnableExamples:
    const adder = toCallerApplicate(`+`, 2)
    doAssert adder.apply(1, 2) == 3
  var params = newNimNode(nnkPar)
  var call = newCall(sym)
  for i in 1..arity:
    let temp = genSym(nskParam, "temp" & $i)
    params.add(temp)
    call.add(temp)
  result = getAst(applicate(params, call))

macro toCallerApplicate*(sym: typed): Applicate =
  ## infers the arity of `sym` from its symbol then calls `toCallerApplicate(sym, arity)`
  ## 
  ## if `sym` is a symbol choice, then the common arity of the choices is used.
  ## if the symbol choices do not share an arity, it will give an error
  runnableExamples:
    const newstr = toCallerApplicate(newString)
    var s: string
    s.setLen(4)
    doAssert newstr.apply(4) == s

    const leq = toCallerApplicate(`<=`)
    doAssert leq.apply(1, 2)
    doAssert leq.apply(2.0, 2.0)
  let arity = inferArity(sym)
  case arity
  of -1:
    error("could not infer arity for non-symbol node " & sym.repr, sym)
  of -2:
    error("could not infer arity for symbol " & sym.repr & " with nil implementation", sym)
  of -3:
    error("arities not shared for choices for symbol " & sym.repr, sym)
  else:
    let identSym = ident repr sym
    result = getAst(toCallerApplicate(identSym, arity))

macro instantiateAs*(appl: ApplicateArg, name: untyped): untyped =
  ## instantiates the applicate in the scope with the given name
  ## 
  ## helps where `apply` syntax isn't enough (for example generics
  ## and overloading)
  runnableExamples:
    instantiateAs(toApplicate(system.succ), incr)
    doAssert incr(1) == 2
    proc foo[T](x, y: T): T {.makeApplicate.} = x + y
    proc bar(x, y: string): string {.makeApplicate.} = x & y
    instantiateAs(foo, baz)
    instantiateAs(bar, baz)
    doAssert baz(1.0, 2.0) == 3.0
    doAssert baz[uint8](1, 2) == 3u8
    doAssert baz("a", "b") == "ab"

    # also works but less efficient as new template is generated:
    instantiateAs(toApplicate(`-`), minus)
    doAssert minus(4) == -4
    doAssert minus(5, 2) == 3

  let n = appl.node
  case n.kind
  of RoutineNodes:
    result = n
    result[0] =
      if name.kind == nnkPrefix and name[0].eqIdent"*":
        postfix(name[1], "*")
      else:
        name
  else:
    let argsSym = genSym(nskParam, "args")
    result = newProc(
      name = name,
      params = [ident"untyped",
        newIdentDefs(argsSym, newTree(nnkBracketExpr, ident"varargs", ident"untyped"))],
      body = newCall(n, argsSym),
      procType = nnkTemplateDef)

macro toSymbol*(appl: ApplicateArg): untyped =
  ## retrieves the symbol of the applicate,
  ## also instantiates routine definitions
  runnableExamples:
    template foo(x: int): int = x + 1
    const incr = toApplicate(foo)
    doAssert toSymbol(incr)(1) == 2
  let a = appl.node
  case a.kind
  of RoutineNodes:
    let templName =
      if a[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
        ident repr a[0]
      else:
        a[0]
    let declaredCheck = prefix(newCall(bindSym"declared", templName), "not")
    result = newStmtList(newTree(nnkWhenStmt, newTree(nnkElifBranch, declaredCheck, a)), templName)
  else:
    result = a

macro forceToSymbol*(appl: ApplicateArg): untyped =
  ## retrieves the symbol of the applicate, also
  ## instantiates routine definitions, without reusing definitions in scope
  let a = appl.node
  case a.kind
  of RoutineNodes:
    let templName =
      if a[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
        ident repr a[0]
      else:
        a[0]
    result = newBlockStmt(newStmtList(a, templName))
  else:
    result = a

macro apply*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate routine
  ## (if not in scope already) then calling it with the given arguments
  runnableExamples:
    const incr = toApplicate(system.succ)
    doAssert incr.apply(1) == 2
  let a = appl.node
  case a.kind
  of RoutineNodes:
    let templName =
      if a[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
        ident repr a[0]
      else:
        a[0]
    let aCall = newNimNode(nnkCall, args)
    aCall.add(templName)
    for arg in args:
      aCall.add(arg)
    let declaredCheck = prefix(newCall(bindSym"declared", templName), "not")
    result = newStmtList(newTree(nnkWhenStmt, newTree(nnkElifBranch, declaredCheck, a)), aCall)
  else:
    result = newCall(a)
    for arg in args: result.add(arg)

macro forceApply*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate routine,
  ## even if already in scope, then calling it with the given arguments
  ## 
  ## realistically, the applicate routine is never in scope, but if you
  ## really come across a case where it is then you can use this
  let a = appl.node
  case a.kind
  of RoutineNodes:
    let templName =
      if a[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
        ident repr a[0]
      else:
        a[0]
    let aCall = newNimNode(nnkCall, args)
    aCall.add(templName)
    for arg in args:
      aCall.add(arg)
    result = newBlockStmt(newStmtList(a, aCall))
  else:
    result = newCall(a)
    for arg in args: result.add(arg)
