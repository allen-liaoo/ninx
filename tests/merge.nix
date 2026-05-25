{
  ninx,
  lib,
  testEq,
  ...
}:

let
  merge =
    ninxExprs:
    (lib.evalModules {
      modules = [
        {
          options.e = lib.mkOption {
            type = ninx.types.nix-expr;
          };
        }
      ]
      ++ map (e: { inherit e; }) ninxExprs;
    }).config.e;
in
with ninx;

[
  (testEq "attrs"
    {
      __rec = false;
      a = 1;
      b = 2;
    }
    (merge [
      { a = 1; }
      { b = 2; }
    ])
  )
]
