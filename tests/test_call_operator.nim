{.experimental: "callOperator".}

import unittest, applicates

test "call operator works":
  applicate double(x): x * 2
  check double(3) == 6
  check 3.double == 6
