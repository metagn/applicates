import macros

type
  ApplateId* = distinct int
    ## index of applate definition in applate cache
  Applate* = static ApplateId
    ## static version of ApplateId to use for argument types

const useCache = defined(applatesUseMacroCache)
when useCache or defined(nimdoc):
  import macrocache
  const applateTemplateCache* = CacheSeq "applates.templates"
    ## the cache containing the anonymous template definition nodes of
    ## each applate. can be indexed by the ID of an applate to receive
    ## its template node, which is meant to be put in user code and invoked
    ## 
    ## uses a compileTime seq by default, if you define `applatesUseMacroCache`
    ## then it will use Nim's `macrocache` types.
else:
  var applateTemplateCache* {.compileTime.}: seq[NimNode]

macro applate*(params, body): untyped =
  ## creates an applate. when anonymous, returns applate id literal
  ## (compatible with Applate/ApplateId). when a name is specified,
  ## it defines that name as a constant with the value being the applate id.
  ## 
  ## note: the return type is untyped by default unlike templates.
  runnableExamples:
    applate foo(name: untyped, val: int):
      let name = val
    
    foo.apply(x, 5)
    doAssert x == 5

    template double(appl: Applate) =
      appl.apply()
      appl.apply()
    
    var c = 0
    when false: # runnableExamples does not handle do: well
      double(applate do:
        double(applate do:
          double(applate do: inc c)))
    else:
      double applate(
        double applate(
          double applate(inc(c))))
    doAssert c == 8
  let id = len(applateTemplateCache)
  result = newCall(bindSym"ApplateId", newLit(id))
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
  if params.kind == nnkExprColonExpr or params.kind == nnkInfix #[ -> ]#:
    returnType = params[1]
    params = params[0]
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
    val
  else:
    nil
  if not name.isNil:
    result = newConstStmt(name, result)
  if params.kind != nnkPar:
    params = newPar(params)
  let formalParams = newTree(nnkFormalParams, returnType)
  for p in params:
    formalParams.add:
      if p.kind == nnkExprColonExpr:
        newIdentDefs(p[0], p[1])
      else:
        newIdentDefs(p, newEmptyNode())
  add(applateTemplateCache,
    newTree(nnkTemplateDef,
      # should be ident here, otherwise declared breaks
      ident repr genSym(nskTemplate, "apply" & $id),
      newEmptyNode(), newEmptyNode(),
      formalParams,
      pragma,
      newEmptyNode(),
      body))

template applate*(body): untyped =
  ## creates anonymous applate with no arguments
  applate((), body)

template `!=>`*(params, body): untyped =
  ## infix version of applate, same syntax
  applate(params, body)

template `!=>`*(body): untyped =
  ## anonymous applate no arguments
  applate(body)

macro apply*(appl: Applate, args: varargs[untyped]): untyped =
  ## applies the applate by injecting the applate template
  ## (if not in scope already) then calling it with the given arguments
  let a = applateTemplateCache[appl.int]
  let templName = ident repr a[0]
  let aCall = newCall(templName)
  for arg in args:
    aCall.add(arg)
  result = quote do:
    when not declared(`templName`):
      `a`
    `aCall`

macro `!`*(appl: Applate, arg: untyped): untyped =
  ## attempted operator syntax for `apply`. has low precedence though
  ## if `arg` is in parentheses then its arguments are broken up,
  ## otherwise it is passed as a single argument
  var args = newNimNode(nnkArgList)
  if arg.kind in {nnkPar, nnkTupleConstr}:
    for a in arg: args.add(a)
  else: args.add(arg)
  result = getAst apply(appl, args)

template `|>`*(arg: untyped, appl: Applate): untyped =
  ## reversed version of `!` with better precedence
  appl ! arg