import ../applicates

template `()`*(appl: ApplicateArg, args: varargs[untyped]): untyped =
  ## Call operator alias for `apply`.
  appl.apply(args)
