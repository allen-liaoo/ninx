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
  (test "prim (int)" (typeEq ntypes.nix-prim 123))
  (test "prim (float)" (typeEq ntypes.nix-prim 123.123))
  (test "prim (bool)" (typeEq ntypes.nix-prim true))
  (test "prim (string)" (typeEq ntypes.nix-prim "abc"))
  (test "prim (path)" (typeEq ntypes.nix-prim ./default.nix))
  (test "var" (typeEq ntypes.nix-var (var "a")))
  (test "access" (typeEq ntypes.nix-access (acc (var "a") "b.c" )))
  (test "attrs" (typeEq ntypes.nix-attrs { a = 123; b.c = 123; }))
  (test "rec-attrs" (typeEq ntypes.nix-attrs (rec-set { a = (var b); b = 123; c.d = (var b); })))
  (test "op" (typeEq ntypes.nix-op (op."//" [])))
  (test "conds" (typeEq ntypes.nix-conds (conds [(ifthen false 1) (ifthen true 2)] true)))
  (test "let-in" (typeEq ntypes.nix-let-in (letin { a = 1; } 2)))
  (test "function"
    (typeEq
      ntypes.nix-function 
      (lambda
        (args { a = null; b = "test"; } null false) 
        (var "b"))))
  (test "application"
    (typeEq
      ntypes.nix-application
        (app
          (lambda "a" (var "a"))
          1)))
  (test "import"
    (typeEq
      ntypes.nix-import
        (importt ./default.nix)))
  (test "raw"
    (typeEq
      ntypes.nix-raw
        (raw "x: x.a.b.c.d")))
]
