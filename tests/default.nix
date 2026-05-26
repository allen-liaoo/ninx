{
  nixpkgsPath ? <nixpkgs>, # necessary for using when evaluating nix str
  nixpkgs ? import nixpkgsPath { },
  lib ? nixpkgs.lib,
  ninxPath ? ../., # for evaluating nix str
  ninx ? import ninxPath { inherit nixpkgs; },
  ninx-lib ? import ../lib.nix { inherit nixpkgs; },
  ninx-test-lib ? import ./_testLib.nix { inherit nixpkgs ninx; },
  ...
}:

let
  globalArgs = {
    inherit
      nixpkgs
      nixpkgsPath
      lib
      ninx
      ninxPath
      ninx-lib
      ninx-test-lib
      testWithMsg
      test
      testEq
      ;
  };

  testWithMsg = name: cond: msg: {
    inherit name;
    run =
      { filename, index }:
      if !cond then
        builtins.warn ''
          ${filename}: Test ${toString index} "${name}" failed
          ${msg}
        '' cond
      else
        cond;
  };

  test = name: cond: testWithMsg name cond "";

  testEq =
    name: expected: actual:
    testWithMsg name (expected == actual) ''
      Expected: ${builtins.toJSON expected},
      Actual: ${builtins.toJSON actual}
    '';

  # run tests in a file, then collect, print, and return stats
  testFile =
    filename:
    let
      tests = import ./${filename} globalArgs;
      stats =
        lib.foldl
          (
            {
              passed,
              failed,
              index,
            }:
            test:
            let
              res = if test.run { inherit filename index; } then 1 else 0;
            in
            {
              passed = passed + res;
              failed = failed + (1 - res);
              index = index + 1;
            }
          )
          {
            passed = 0;
            failed = 0;
            index = 0;
          }
          tests;
    in
    builtins.trace "${filename}: ${toString stats.passed}/${toString (builtins.length tests)} tests passed\n" stats;

  # run testFile on directory (list of files)
  testDir = dirname: map (f: testFile (dirname + "/" + f)) (import ./${dirname});
in

lib.foldl (failed: stat: failed + stat.failed) 0 (
  [
    (testFile "types.nix")
    (testFile "serialize-eval.nix")
    (testFile "merge.nix")
  ]
  ++ (testDir "lib-tests")
)
