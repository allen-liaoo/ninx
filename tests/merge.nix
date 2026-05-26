# Tests merging of values
{
  ninx,
  ninxPath,
  ninx-test-lib,
  lib,

  nixpkgsPath,
  testWithMsg,
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
            type = ninx.types.expr;
          };
        }
      ]
      ++ map (e: { inherit e; }) ninxExprs;
    }).config.e;

  ninxInStore = builtins.path { path = ninxPath; };

  testMergeError =
    testName: errorMsg: ninxExprs:
    let
      code = ninx-test-lib.toString ninxExprs; # important: dont serialize! we want the internal representation to show up
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
      evalRes = ninx-test-lib.evalNixStr {
        name = testName;
        expr = evalCode;
      };
      result = !evalRes.success && (builtins.match ".*${errorMsg}.*" evalRes.error) != null; # errors with expected msg substring
    in
    testWithMsg testName result "Configs: ${code}\nGot error: \n${evalRes.error}";
in
with ninx;

[
  # Primitive type merging tests
  
  # null
  (testEq "prim-null-same" null (merge [ null null ]))
  
  # boolean
  (testEq "prim-bool-same-true" true (merge [ true true ]))
  (testEq "prim-bool-same-false" false (merge [ false false ]))
  (testMergeError "prim-bool-diff" "conflicting definition values" [ true false ])
  
  # integer
  (testEq "prim-int-same" 123 (merge [ 123 123 ]))
  (testMergeError "prim-int-diff" "conflicting definition values" [ 1 2 ])
  
  # float
  (testEq "prim-float-same" 1.5 (merge [ 1.5 1.5 ]))
  (testMergeError "prim-float-diff" "conflicting definition values" [ 1.5 2.5 ])
  
  # string
  (testEq "prim-string-same" "hello" (merge [ "hello" "hello" ]))
  (testMergeError "prim-string-diff" "conflicting definition values" [ "hello" "world" ])
  
  # path
  (testEq "prim-path-same"
    (builtins.readFile ./default.nix)
    (builtins.readFile (merge [ ./default.nix ./default.nix ])))
  (testMergeError "prim-path-diff" "conflicting definition values" [
    ./default.nix
    ./merge.nix
  ])
  
  # list of prims
  (testEq "prim-list-merge" [ 1 2 3 1 2 3 ] (merge [ [ 1 2 3 ] [ 1 2 3 ] ]))
  (testEq "prim-list-mkBefore" [ 1 2 3 4 5 6 ] (merge [ (lib.mkBefore [ 1 2 3 ]) [ 4 5 6 ] ]))
  (testEq "prim-list-mkAfter" [ 1 2 3 4 5 6 ] (merge [ [ 1 2 3 ] (lib.mkAfter [ 4 5 6 ]) ]))

  # attrs
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

  # recursive attrs
  (testEq "recc-merge"
    (recc { a = (var "b"); b = 2; })
    (merge [
      (recc { a = (var "b"); })
      (recc { b = 2; })
    ])
  )

  # Unmergeable types

  # this case produces a weird error message because they are different unmergeable types, but the code is not wrong
  # TypeError: The option `e` is neither a value of type ... or ...
  (testMergeError "prim-diff-type" "TypeError" [
    # if I put "a" here instead of attrset, the error msg makes sense (defined multiple times), not sure why
    { a = 1; }
    2
  ])

  # variable
  (testMergeError "var-unmergeable" "defined multiple times" [
    (var "a")
    (var "b")
  ])

  # operator
  (testMergeError "op-unmergeable" "defined multiple times" [
    (op."+" 1 2)
    (op."+" 3 4)
  ])

  # application
  (testMergeError "app-unmergeable" "defined multiple times" [
    (app (raw "builtins.add") 1)
    (app (raw "builtins.add") 2)
  ])

  # import
  (testMergeError "import-unmergeable" "defined multiple times" [
    (importt ./default.nix)
    (importt ./merge.nix)
  ])

]
