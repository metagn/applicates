import macros

type
  ApplicatePtr* = distinct int
    ## "pointer to" (index of) applicate AST
  Applicate* = static ApplicatePtr
    ## static type of ApplicatePtr to use for types of arguments

const useCache = defined(applicatesUseMacroCache)
when useCache or defined(nimdoc):
  import macrocache
  const applicateRoutineCache* = CacheSeq "applicates.routines"
    ## the cache containing the routine definition nodes of
    ## each applicate. can be indexed by the ID of an applicate to receive
    ## its routine node, which is meant to be put in user code and invoked
    ## 
    ## uses a compileTime seq by default, if you define `applicatesUseMacroCache`
    ## then it will use Nim's `macrocache` types.
else:
  var applicateRoutineCache* {.compileTime.}: seq[NimNode]

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
    result = newStmtList()
    for st in body: result.add(getAst(makeApplicate(st)))
  of RoutineNodes - {nnkDo, nnkLambda}:
    let id = len(applicateRoutineCache)
    result = newConstStmt(ident repr body[0], newCall(bindSym"ApplicatePtr", newLit(id)))
    let body = copy(body)
    body[0] = ident repr gensym(
      case body.kind
      of nnkTemplateDef: nskTemplate
      of nnkMacroDef: nskMacro
      of nnkProcDef: nskProc
      of nnkConverterDef: nskConverter
      of nnkIteratorDef: nskIterator
      of nnkMethodDef: nskMethod
      of nnkFuncDef: nskFunc
      else: nskTemplate, "appl" & $id)
    add(applicateRoutineCache, body)
  else:
    error("cannot turn non-routine into applicate", body)

macro realMakeTypedApplicate(body: typed): untyped =
  result = getAst(makeApplicate(body))

macro makeTypedApplicate*(body: untyped): untyped =
  ## Registers applicate with given routine(s), but forces it to be type
  ## checked first (`body` is only `untyped` here because a `used` pragma
  ## is injected to get rid of a warning). This lets it use symbols that are
  ## accessible during the registering, but if the routine is not a template
  ## then *only* local symbols are accessible.
  ## 
  ## Works best for templates and macros, so `applicate` uses this.
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
    result = newStmtList()
    for st in body: result.add(getAst(makeTypedApplicate(st)))
  of RoutineNodes - {nnkDo, nnkLambda}:
    if body[4].kind == nnkEmpty:
      body[4] = newTree(nnkPragma, ident"used")
    else:
      body[4].add(ident"used")
    result = getAst(realMakeTypedApplicate(body))
  else:
    error("cannot turn non-routine into applicate", body)

macro applicate*(params, body): untyped =
  ## generates a template based on the params and body and registers it as a typed
  ## applicate. when anonymous, returns applicate id literal
  ## (compatible with Applicate/ApplicatePtr). when a name is specified (using
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

    template double(appl: Applicate) =
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
  elif params.kind == nnkPragma:
    pragma = params
    params = newNimNode(nnkPar)
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
  elif params.kind == nnkPragma:
    pragma = params
    params = newNimNode(nnkPar)
  let name = if params.kind == nnkInfix and params[0].eqIdent"*":
    let val = postfix(params[0], "*")
    params = params[1]
    val
  elif params.kind in {nnkCall, nnkObjConstr}:
    let newParams = newNimNode(nnkPar)
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
    params = newPar(params)
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
      of nnkIdent:
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
  let templ = newTree(nnkTemplateDef,
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

template applicate*(body): untyped =
  ## creates anonymous applicate with no arguments
  applicate((), body)

template `!=>`*(params, body): untyped =
  ## infix version of `applicate`, same syntax
  applicate(params, body)

template `!=>`*(body): untyped =
  ## anonymous applicate no arguments
  applicate(body)

proc node*(appl: ApplicatePtr): NimNode {.compileTime.} =
  ## retrieves the node of the applicate from the cache
  applicateRoutineCache[appl.int]

macro apply*(appl: Applicate, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate routine
  ## (if not in scope already) then calling it with the given arguments
  let a = appl.node
  let templName = ident repr a[0]
  let aCall = newCall(templName)
  for arg in args:
    aCall.add(arg)
  result = quote do:
    when not declared(`templName`):
      `a`
    `aCall`

when defined(nimHasCallOperator) or defined(nimdoc):
  template `()`*(appl: Applicate, args: varargs[untyped]): untyped =
    ## Call operator alias for `apply`. Must turn on experimental Nim feature
    ## `callOperator` to use. Note that this experimental feature seems to be very broken. 
    appl.apply(args)

macro `|>`*(arg: untyped, appl: Applicate): untyped =
  ## attempted operator syntax for `apply`. if `arg` is in parentheses
  ## then its arguments are broken up, otherwise it is passed as a single argument
  var args = newNimNode(nnkArgList)
  if arg.kind in {nnkPar, nnkTupleConstr}:
    for a in arg: args.add(a)
  else: args.add(arg)
  result = getAst apply(appl, args)
