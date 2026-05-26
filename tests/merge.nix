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
  # Primitive expressions (common: allow merging when equal)
  
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
  
  # list of prims (just like listOf)
  (testEq "prim-list-merge" [ 1 2 3 1 2 3 ] (merge [ [ 1 2 3 ] [ 1 2 3 ] ]))
  (testEq "prim-list-mkBefore" [ 1 2 3 4 5 6 ] (merge [ (lib.mkBefore [ 1 2 3 ]) [ 4 5 6 ] ]))
  (testEq "prim-list-mkAfter" [ 1 2 3 4 5 6 ] (merge [ [ 1 2 3 ] (lib.mkAfter [ 4 5 6 ]) ]))

  # attrs (merge however u'd like!)
  (testEq "attrs"
    (attrs {
      a = 1;
      b = 2;
    })
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

   # variable
   (testEq "var-merge-same" (var "a") (merge [ (var "a") (var "a") ]))
   (testMergeError "var-merge-diff" "conflicting definition values" [
     (var "a")
     (var "b")
   ])

   # import
   (testEq "import-merge-same" (importt ./default.nix) (merge [ (importt ./default.nix) (importt ./default.nix) ]))
   (testMergeError "import-merge-diff" "conflicting definition values" [
     (importt ./default.nix)
     (importt ./merge.nix)
   ])

  # Unmergeable expressions

  # this case produces a weird error message because they are different unmergeable types, but the code is not wrong
  # TypeError: The option `e` is neither a value of type ... or ...
  (testMergeError "prim-diff-type" "TypeError" [
    # if I put "a" here instead of attrset, the error msg makes sense (defined multiple times), not sure why
    { a = 1; }
    2
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

  # Mergeable expressions (interesting cases)

  # let-in merging - merge let bindings
  (testEq "letin-merge-bindings"
    (letin { a = 1; b = 2; c = 3; } 99)
    (merge [
      (letin { a = 1; b = 2; } 99)
      (letin { c = 3; } 99)
    ])
  )

   # let-in merging - merge "in" expressions (attrsets)
  (testEq "letin-merge-in"
    (letin { a = 10; b = 20; } (attrs { x = 1; y = 2; }))
    (merge [
      (letin { a = 10; } { x = 1; })
      (letin { b = 20; } { y = 2; })
    ])
  )

  # conditional merging - merge conditions list and else
  (testEq "conds-merge"
    (conds [ (ifthen false 1) (ifthen true 2) (ifthen false 3) ] (attrs { x = 1; y = 2; }))
    (merge [
      (conds [ (ifthen false 1) (ifthen true 2) ] { x = 1; })
      (conds (lib.mkAfter [ (ifthen false 3) ]) { y = 2; })
    ])
  )

  # function merging - merge function arguments
  (testEq "function-merge-args"
    (lambda (args { a = null; b = 1; c = 2; } null false) 99)
    (merge [
      (lambda { a = null; b = 1; } 99)
      (lambda { a = null; c = 2; } 99)
    ])
  )

  # function merging with patterns 
  (testEq "function-merge-args-patterns"
    (lambda (args { a = null; b = 1; c = null; } "attrs" true) 99)
    (merge [
      (lambda (args { a = null; b = 1; } "attrs" true) 99)
      (lambda (args { a = null; c = null; } "attrs" true) 99)
    ])
  )

  # function merging - merge function bodies (when they're attrsets)
  (testEq "function-merge-body"
    (lambda "x" (attrs { a = 1; b = 2; }))
    (merge [
      (lambda "x" { a = 1; })
      (lambda "x" { b = 2; })
    ])
  )

]
