# Tests serialized code by evaluating it
{
  ninx,
  ninx-test-lib,
  testEq,
  ...
}:

let
  serEval =
    name: nix-expr:
    (ninx-test-lib.evalNixStr {
      inherit name;
      expr = ninx.serialize nix-expr;
    }).result;

  # testSerEq on serialized and evaluated code
  testSerEq =
    testName: expected: nix-expr:
    testEq testName expected (serEval testName nix-expr);
in
with ninx;
[
  (testSerEq "null" null null)

  (testSerEq "number" 123 123)

  (testSerEq "float" 123.123 123.123)

  (testSerEq "true" true true)

  (testSerEq "false" false false)

  (testSerEq "string" "a" "a")

  (testEq "path" (builtins.readFile ./default.nix) (builtins.readFile (serEval "path" ./default.nix)))

  (testSerEq "list"
    [
      0
      0.1
      true
      "abc"
      { a.b = 1; }
      [ null ]
    ]
    [
      0
      0.1
      true
      "abc"
      { a.b = 1; }
      [ null ]
    ]
  )

  (testSerEq "attrs" { a = 1; } { a = 1; })

  (testSerEq "rec-attrs"
    rec {
      a = b;
      b = 1;
    }
    (recc {
      a = var "b";
      b = 1;
    })
  )

  (testSerEq "operators" 10 (op."+" (op."*" 2 3) 4))

  (testSerEq "if-then-else"
    (
      if false then
        1
      else if true then
        2
      else
        3
    )
    (
      conds [
        (ifthen false 1)
        (ifthen true 2)
      ] 3
    )
  )

  (testSerEq "let-in"
    {
      a = 1;
      b.c = 2;
      b.d = 3;
    }
    (
      letin {
        r = {
          a = 1;
          b.c = 2;
          b.d = 3;
        };
      } (var "r")
    )
  )

  (testSerEq "application" 7 (
    app (raw "builtins.add") [
      3
      4
    ]
  ))

  (testSerEq "fibonacci" 8 (
    letin {
      fib = lambda "n" (
        let
          n = var "n";
          eqn = e: op."==" n e;
          subn = e: op."-" n e;
        in
        conds [
          (ifthen (op."||" (eqn 1) (eqn 0)) (var "n"))
        ] (op."+" (app "fib" (subn 1)) (app "fib" (subn 2)))
      );
    } (app "fib" 6)
  ))
]
