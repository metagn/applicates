import macros

type
  ApplicateId* = distinct int
    ## index of applicate definition in applicate cache
  Applicate* = static ApplicateId
    ## static version of ApplicateId to use for argument types

const useCache = defined(applicatesUseMacroCache)
when useCache or defined(nimdoc):
  import macrocache
  const applicateTemplateCache* = CacheSeq "applicates.templates"
    ## the cache containing the anonymous template definition nodes of
    ## each applicate. can be indexed by the ID of an applicate to receive
    ## its template node, which is meant to be put in user code and invoked
    ## 
    ## uses a compileTime seq by default, if you define `applicatesUseMacroCache`
    ## then it will use Nim's `macrocache` types.
else:
  var applicateTemplateCache* {.compileTime.}: seq[NimNode]

macro applicate*(params, body): untyped =
  ## creates an applicate. when anonymous, returns applicate id literal
  ## (compatible with Applicate/ApplicateId). when a name is specified,
  ## it defines that name as a constant with the value being the applicate id.
  ## 
  ## note: the return type is untyped by default unlike templates.
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
  let id = len(applicateTemplateCache)
  result = newCall(bindSym"ApplicateId", newLit(id))
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
  add(applicateTemplateCache,
    newTree(nnkTemplateDef,
      # should be ident here, otherwise declared breaks
      ident repr genSym(nskTemplate, "apply" & $id),
      newEmptyNode(), newEmptyNode(),
      formalParams,
      pragma,
      newEmptyNode(),
      body))

template applicate*(body): untyped =
  ## creates anonymous applicate with no arguments
  applicate((), body)

template `!=>`*(params, body): untyped =
  ## infix version of applicate, same syntax
  applicate(params, body)

template `!=>`*(body): untyped =
  ## anonymous applicate no arguments
  applicate(body)

macro apply*(appl: Applicate, args: varargs[untyped]): untyped =
  ## applies the applicate by injecting the applicate template
  ## (if not in scope already) then calling it with the given arguments
  let a = applicateTemplateCache[appl.int]
  let templName = ident repr a[0]
  let aCall = newCall(templName)
  for arg in args:
    aCall.add(arg)
  result = quote do:
    when not declared(`templName`):
      `a`
    `aCall`

macro `!`*(appl: Applicate, arg: untyped): untyped =
  ## attempted operator syntax for `apply`. has low precedence though
  ## if `arg` is in parentheses then its arguments are broken up,
  ## otherwise it is passed as a single argument
  var args = newNimNode(nnkArgList)
  if arg.kind in {nnkPar, nnkTupleConstr}:
    for a in arg: args.add(a)
  else: args.add(arg)
  result = getAst apply(appl, args)

template `|>`*(arg: untyped, appl: Applicate): untyped =
  ## reversed version of `!` with better precedence
  appl ! arg