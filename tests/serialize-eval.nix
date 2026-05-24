{
  nixpkgs,
  ninx,
  ...
}:

let
  # serialize and evaluate code
  serEval =
    nix-expr:
    let
      serialized = ninx.serialize nix-expr;
      script =
        nixpkgs.runCommand "eval-result.json"
          {
            requiredSystemFeatures = [ "recursive-nix" ];
            NIX_PATH = "nixpkgs=${<nixpkgs>}";
          }
          ''
            ${nixpkgs.nix}/bin/nix --extra-experimental-features nix-command eval --json --show-trace --expr '${serialized}' > $out
          '';
    in
    (builtins.fromJSON (builtins.readFile script));
in
with ninx;

assert 123 == serEval 123;

assert 123.123 == serEval 123.123;

assert true == (serEval true);

assert false == (serEval false);

assert "a" == serEval "a";

assert { a = 1; } == serEval { a = 1; };

assert
  rec {
    a = b;
    b = 1;
  } == serEval (rec-set {
    a = var "b";
    b = 1;
  });

assert (builtins.readFile ./default.nix) == (builtins.readFile (serEval ./default.nix));

assert
  10 == serEval (
    op."+" [
      (op."*" [
        2
        3
      ])
      4
    ]
  );

assert
  (
    if false then
      1
    else if true then
      2
    else
      3
  ) == serEval (
    conds [
      (ifthen false 1)
      (ifthen true 2)
    ] 3
  );

assert
  {
    a = 1;
    b.c = 2;
    b.d = 3;
  } == serEval (
    letin {
      r = {
        a = 1;
        b.c = 2;
        b.d = 3;
      };
    } (var "r")
  );

assert
  7 == serEval (
    app (raw "builtins.add") [
      3
      4
    ]
  );

assert
  8 == serEval (
    letin {
      fib = lambda "n" (
        let
          n = var "n";
          eqn =
            e:
            op."==" [
              n
              e
            ];
          subn =
            e:
            op."-" [
              n
              e
            ];
        in
        conds
          [
            (ifthen (op."||" [
              (eqn 1)
              (eqn 0)
            ]) (var "n"))
          ]
          (
            op."+" [
              (app "fib" (subn 1))
              (app "fib" (subn 2))
            ]
          )
      );
    } (app "fib" 6)
  );

true
