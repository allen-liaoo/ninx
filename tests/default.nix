{
  nixpkgs ? import <nixpkgs> { },
  lib ? nixpkgs.lib,
  ninx ? import ../default.nix { },
}:

let
  test = name: t: {
    inherit name;
    run = { filename, index }:
      if !t then 
        builtins.warn "${filename}: Test ${toString index} \"${name}\" failed\n" t
      else t;
  };
  testEq = name: expected: actual: {
    inherit name;
    run = { filename, index }: 
      let 
        result = expected == actual;
      in
      if !result then
        builtins.warn ''
          ${filename}: Test ${toString index} "${name}" failed
            Expected: ${builtins.toJSON expected},
            Actual: ${builtins.toJSON actual}
          '' result
      else result;
  };
  args = {
    inherit
      nixpkgs
      lib
      ninx
      test
      testEq
      ;
  };

  testFile =
    filename:
      let
        tests = import ./${filename} args;
        stats = lib.foldl
          (
            { passed, failed, index }:
            test: let
              res = if test.run { inherit filename index; } then 1 else 0;
            in {
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
in

lib.foldl 
  (failed: stat:
    failed + stat.failed) 
  0
  [
  #(testFile "merge.nix")
    (testFile "serialize-eval.nix")
  ]
