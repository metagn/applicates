import macros, macrocache

const cacheUseTable = defined(applicatesCacheUseTable) and not defined(nimdoc)

when cacheUseTable:
  type ApplicateKey* = string
else:
  type ApplicateKey* = int
    ## "pointer to" (index of) applicate AST. if you define
    ## ``applicatesCacheUseTable`` this will be a string

type
  Applicate* = distinct ApplicateKey
    ## distinct version of ApplicateKey
  ApplicateArg* = static Applicate
    ## `static Applicate` to use for types of arguments

const applicateCache* =
  when cacheUseTable:
    CacheTable "applicates.applicates.table"
  else:
    CacheSeq "applicates.applicates"
  ## the cache containing the routine definition nodes of
  ## each applicate. can be indexed by the ID of an applicate to receive
  ## its routine node, which is meant to be put in user code and invoked
  ## 
  ## if you define `applicatesCacheUseTable` then it will use
  ## a `CacheTable` with unique strings

template applicateCount*(): int = # this breaks when `proc {.compileTime.}`
  ## total number of registered applicates
  len(applicateCache)

proc registerApplicate*(node: NimNode, num: int = applicateCount()): ApplicateKey {.compileTime.} =
  result = when cacheUseTable: $num else: num
  # ^ is this even going to work in the future
  when cacheUseTable:
    applicateCache[result] = copy node
  else:
    add(applicateCache, copy node)

proc inferArity*(sym: NimNode): int =
  ## infers arity of symbol
  ## 
  ## -1 if sym is not a symbol, -2 if implementation
  ## of a symbol was nil, -3 if symbol choice arities
  ## do not match
  case sym.kind
  of nnkSym:
    let impl = sym.getImpl
    if impl.isNil: return -2 # symbol impl nil
    let fparams = impl[3]
    for i in 1..<fparams.len:
      result += fparams[i].len - 2
  of nnkClosedSymChoice, nnkOpenSymChoice:
    for i in 0..<sym.len:
      let s = sym[i]
      let impl = s.getImpl
      if impl.isNil: return -2 # symbol impl nil
      let fparams = impl[3]
      var arity = 0
      for i in 1..<fparams.len:
        arity += fparams[i].len - 2
      if i == 0:
        result = arity
      elif result != arity:
        result = -3 # symbol arities not shared
  else:
    result = -1

proc node*(appl: Applicate): NimNode {.compileTime.} =
  ## retrieves the node of the applicate from the cache
  result = applicateCache[(when cacheUseTable: string else: int)(appl)]
  # macrocache should copy automatically, but it doesn't yet:
  result = copy result

proc arity*(appl: Applicate): int {.compileTime.} =
  ## gets arity of applicate. check `inferArity` for meaning of
  ## negative values
  runnableExamples:
    import ../applicates, ./operators
    doAssert static(arity((x, y) ==> x + y)) == 2
    doAssert static(arity(a ==> a)) == 1
    doAssert static(arity(==> 3)) == 0
  let n = appl.node
  case n.kind
  of RoutineNodes:
    let fparams = n[3]
    var res = 0
    for i in 1..<fparams.len:
      res += fparams[i].len - 2
    result = res
  else:
    result = inferArity(n)
