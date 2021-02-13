{.experimental: "callOperator".}

import unittest, applicates

from applicates/operators import `()`

test "call operator works":
  applicate double do (x): x * 2
  check double(3) == 6
  check 3.double == 6

test "infix call":
  applicate `++` do (x, y): x + y

  check 1 ++ 2 == 3
