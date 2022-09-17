when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import applicates, applicates/calloperator

test "call operator works":
  applicate double do (x): x * 2
  check double(3) == 6
  check 3.double == 6

test "infix call":
  applicate `++` do (x, y): x + y

  check 1 ++ 2 == 3
