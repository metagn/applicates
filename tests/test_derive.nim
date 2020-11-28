import unittest, applates, hashes

type Class = Applate

template derive(T: type, intf: Class) =
  intf.apply(T)

template mix(h: var Hash, i) = h = h !& i
template finish(h: var Hash) = h = !$ h

template class(name, decls) =
  applate `name`(Self):
    decls

class Hashable:
  proc hash(x: Self): Hash =
    for f in x.fields:
      mix result, f.hash
    finish result

test "derive object":
  type Foo = object
    name: string
    age: int
  
  derive Foo, Hashable

  let foo = Foo(name: "John", age: 30)
  check foo.hash is Hash