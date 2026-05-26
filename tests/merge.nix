{
  ninx,
  ninxPath,
  nixpkgsPath,
  lib,
  testWithMsg,
  testEq,
  evalNixStr,
  ...
}:

let
  merge =
    ninxExprs:
    (lib.evalModules {
      modules = [
        {
          options.e = lib.mkOption {
            type = ninx.types.expr;
          };
        }
      ]
      ++ map (e: { inherit e; }) ninxExprs;
    }).config.e;

  ninxInStore = builtins.path { path = ninxPath; };

  testMergeError =
    testName:
    errorMsg:
    ninxExprs:
    let
      code = ninx.serialize ninxExprs;
      evalCode = ''
        let
          nixpkgs = import ${nixpkgsPath} {};
          lib = nixpkgs.lib;
          ninx = import ${ninxInStore} {
            inherit nixpkgs;
          };
        in
        (lib.evalModules {
          modules = [
            {
              options.e = lib.mkOption {
                type = ninx.types.expr;
              };
            }
          ]
          ++ map (e: { inherit e; }) ${code};
        }).config.e
      '';
      evalRes = evalNixStr { name = testName; expr = evalCode; };
      result = !evalRes.success && (builtins.match ".*${errorMsg}.*" evalRes.error) != null; # errors with expected msg substring
    in
    testWithMsg testName result "Code: ${code}\nGot error: \n${evalRes.error}";
in
with ninx;

[
  (testMergeError "prim-same-type" "conflicting definition values" [ (op."~" 1) 2 ])
  (testMergeError "prim-diff-type" "conflicting definition values" [ { a = 1; } 2 ])

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
