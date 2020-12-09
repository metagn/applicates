import macros

const cacheUseTable = defined(applicatesCacheUseTable) and not defined(nimdoc)
const useCache = defined(applicatesUseMacroCache) and not defined(nimdoc)

when cacheUseTable:
  type Applicate* = distinct string
else:
  type Applicate* = distinct int
    ## "pointer to" (index of) applicate AST. if you define
    ## ``applicatesCacheUseTable`` this will be a distinct string

type ApplicateArg* = static Applicate
  ## `static Applicate` to use for types of arguments

when cacheUseTable:
  import macrocache
  const applicateRoutineCache* = CacheTable "applicates.routines.table"
elif useCache:
  import macrocache
  const applicateRoutineCache* = CacheSeq "applicates.routines"
else:
  var applicateRoutineCache* {.compileTime.}: seq[NimNode]
    ## the cache containing the routine definition nodes of
    ## each applicate. can be indexed by the ID of an applicate to receive
    ## its routine node, which is meant to be put in user code and invoked
    ## 
    ## uses a compileTime seq by default, if you define `applicatesUseMacroCache`
    ## then it will use Nim's `macrocache` types, if you define
    ## `applicatesCacheUseTable` then it will use a `CacheTable` with
    ## unique strings

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
    let num = len(applicateRoutineCache)
    let key = when cacheUseTable: $num else: num
    result = newCall(bindSym"Applicate", newLit(key))
    if body[0].kind != nnkEmpty:
      result = newConstStmt(
        if body[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
          ident repr body[0]
        else:
          body[0], result)
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
    when cacheUseTable:
      applicateRoutineCache[key] = b
    else:
      add(applicateRoutineCache, b)
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
  ## Injects `used` pragma into `body` and calls `makeApplicateFromTyped`.
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
    when false: # runnableExamples does not handle do: well
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
  if params.kind != nnkPar:
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
  if body.kind == nnkDo:
    if body[3][0].kind == nnkEmpty: body[3][0] = ident"untyped"
    let templ = newNimNode(nnkTemplateDef, body)
    for s in body:
      templ.add(s)
    result = getAst(makeTypedApplicate(templ))
  else:
    let args = newPar()
    result = getAst(applicate(args, body))

template `!=>`*(params, body): untyped =
  ## infix version of `applicate`, same parameter syntax
  runnableExamples:
    doAssert (x !=> x + 1).apply(2) == 3
    const foo = (a, b) !=> a + b
    doAssert foo.apply(1, 2) == 3
  applicate(params, body)

template `!=>`*(body): untyped =
  ## same as ``applicate(body)``
  applicate(body)

template `\=>`*(params, body): untyped =
  ## alias for `!=>`
  runnableExamples:
    doAssert (x \=> x + 1).apply(2) == 3
    const foo = (a, b) \=> a + b
    doAssert foo.apply(1, 2) == 3
  applicate(params, body)

template `\=>`*(body): untyped =
  ## alias for `!=>`
  applicate(body)

macro toUntyped*(sym: untyped, arity: static int): Applicate =
  ## creates an applicate with `n` = `arity` untyped parameters
  ## that calls the given symbol `sym`
  runnableExamples:
    const adder = toUntyped(`+`, 2)
    doAssert adder.apply(1, 2) == 3
  var params = newNimNode(nnkPar)
  var call = newCall(sym)
  for i in 1..arity:
    let temp = genSym(nskParam, "temp" & $i)
    params.add(temp)
    call.add(temp)
  result = getAst(applicate(params, call))

macro toUntyped*(sym: typed): Applicate =
  ## infers the arity of `sym` from its symbol then calls `toUntyped(sym, arity)`
  ## 
  ## if `sym` is a symbol choice, then the common arity of the choices is used.
  ## if the symbol choices do not share an arity, it will give an error
  runnableExamples:
    const newstr = toUntyped(newString)
    var s: string
    s.setLen(4)
    doAssert newstr.apply(4) == s

    const leq = toUntyped(`<=`)
    doAssert leq.apply(1, 2)
    doAssert leq.apply(2.0, 2.0)
  case sym.kind
  of nnkSym:
    let impl = sym.getImpl
    if impl.isNil:
      error("implementation of symbol " & sym.repr & " for toUntyped was nil", sym)
    let fparams = impl[3]
    var arity = 0
    for i in 1..<fparams.len:
      arity += fparams[i].len - 2
    let identSym = ident repr sym
    result = getAst(toUntyped(identSym, arity))
  of nnkClosedSymChoice, nnkOpenSymChoice:
    var commonArity = 0
    for i in 0..<sym.len:
      let s = sym[i]
      let impl = s.getImpl
      if impl.isNil:
        # maybe ignore these?
        error("implementation of symbol choice " & s.repr & " for toUntyped was nil", sym)
      let fparams = impl[3]
      var arity = 0
      for i in 1..<fparams.len:
        arity += fparams[i].len - 2
      if i == 0:
        commonArity = arity
      elif commonArity != arity:
        error("conflicting arities for symbol " & sym.repr & ": " &
          $commonArity & " and " & $arity, s)
    let identSym = ident repr sym
    result = getAst(toUntyped(identSym, commonArity))
  else:
    error("non-symbol was passed to unary toUntyped, with kind " & $sym.kind, sym) 

proc node*(appl: Applicate): NimNode {.compileTime.} =
  ## retrieves the node of the applicate from the cache
  applicateRoutineCache[(when cacheUseTable: string else: int)(appl)]

macro arity*(appl: ApplicateArg): static int =
  ## gets arity of applicate
  runnableExamples:
    doAssert arity((x, y) !=> x + y) == 2
    doAssert arity(a !=> a) == 1
    doAssert arity(!=> 3) == 0
  let fparams = appl.node[3]
  var res = 0
  for i in 1..<fparams.len:
    res += fparams[i].len - 2
  result = newLit(res)

macro instantiateAs*(appl: ApplicateArg, name: untyped): untyped =
  ## instantiates the applicate in the scope with the given name
  ## 
  ## helps where `apply` syntax isn't enough (for example generics
  ## and overloading)
  runnableExamples:
    instantiateAs(x !=> x + 1, incr)
    doAssert incr(1) == 2
    proc foo[T](x, y: T): T {.makeApplicate.} = x + y
    proc bar(x, y: string): string {.makeApplicate.} = x & y
    instantiateAs(foo, baz)
    instantiateAs(bar, baz)
    doAssert baz(1.0, 2.0) == 3.0
    doAssert baz[uint8](1, 2) == 3u8
    doAssert baz("a", "b") == "ab"
  result = copy appl.node
  result[0] =
    if name.kind == nnkPrefix and name[0].eqIdent"*":
      postfix(name[1], "*")
    else:
      name

macro apply*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate routine
  ## (if not in scope already) then calling it with the given arguments
  runnableExamples:
    const incr = x !=> x + 1
    doAssert incr.apply(1) == 2
  let a = appl.node
  let templName =
    if a[0].kind in {nnkSym, nnkClosedSymChoice, nnkOpenSymChoice}:
      ident repr a[0]
    else:
      a[0]
  let aCall = newNimNode(nnkCall, args)
  aCall.add(templName)
  for arg in args:
    aCall.add(arg)
  result = quote do:
    when not declared(`templName`):
      `a`
    `aCall`

macro forceApply*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate routine,
  ## even if already in scope, then calling it with the given arguments
  ## 
  ## realistically, the applicate routine is never in scope, but if you
  ## really come across a case where it is then you can use this
  let a = appl.node
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

macro `|`*(appl: ApplicateArg, arg: untyped): untyped =
  ## attempted operator syntax for `apply`. if `arg` is in parentheses
  ## then its arguments are broken up, otherwise it is passed as a single argument
  ## 
  ## note that you can undefine operators you don't want via ``import except``
  runnableExamples:
    doAssert (x !=> x + 1) | 1 == 2
    const foo = x !=> x + 1
    doAssert foo | 1 == 2
    doAssert ((a, b) !=> a + b) | (1, 2) == 3
  var args = newNimNode(nnkArgList, arg)
  if arg.kind in {nnkPar, nnkTupleConstr}:
    for a in arg: args.add(a)
  else: args.add(arg)
  result = getAst apply(appl, args)

template `|<`*(arg: untyped, appl: ApplicateArg): untyped =
  ## flipped `|`
  appl | arg

macro `\`*(call: untyped): untyped =
  ## converts a call expression to an applicate call expression
  ## 
  ## supports dot calls, if the given expression is not a dot expression
  ## or call or command then it will simply apply it with no arguments
  ## 
  ## also supports command calls but not sure how you'd use it with the syntax
  runnableExamples:
    const foo = x !=> x + 1
    doAssert \foo(1) == 2
    doAssert \1.foo == 2
    const bar = (a, b) !=> a + b
    doAssert \bar(1, 2) == 3
    doAssert \1.bar(2) == 3
    const baz = !=> 10
    doAssert \baz() == 10
    doAssert \baz == 10
  result = newNimNode(nnkCall, call)
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
