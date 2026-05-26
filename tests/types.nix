{
  ninx,
  test,
  ...
}:

let
  ntypes = ninx.types;
  typeEq = type: val: type.check val;
in
with ninx;

[
  (test "prim (null)" (typeEq ntypes.prim null))
  (test "prim (int)" (typeEq ntypes.prim 123))
  (test "prim (float)" (typeEq ntypes.prim 123.123))
  (test "prim (bool)" (typeEq ntypes.prim true))
  (test "prim (string)" (typeEq ntypes.prim "abc"))
  (test "prim (path)" (typeEq ntypes.prim ./default.nix))
  (test "var" (typeEq ntypes.var (var "a")))
  (test "access" (typeEq ntypes.access (acc (var "a") "b.c" )))
  (test "attrs" (typeEq ntypes.attrs { a = 123; b.c = 123; }))
  (test "rec-attrs" (typeEq ntypes.attrs (recc { a = (var b); b = 123; c.d = (var b); })))
  (test "op" (typeEq ntypes.op (op."//" {} {})))
  (test "conds" (typeEq ntypes.conds (conds [(ifthen false 1) (ifthen true 2)] true)))
  (test "let-in" (typeEq ntypes.let-in (letin { a = 1; } 2)))
  (test "function"
    (typeEq
      ntypes.function 
      (lambda
        (args { a = null; b = "test"; } null false) 
        (var "b"))))
  (test "application"
    (typeEq
      ntypes.application
        (app
          (lambda "a" (var "a"))
          1)))
  (test "import"
    (typeEq
      ntypes.import
        (importt ./default.nix)))
  (test "raw"
    (typeEq
      ntypes.raw
        (raw "x: x.a.b.c.d")))
]
