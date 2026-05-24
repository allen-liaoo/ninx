let
  nixpkgs = import <nixpkgs> { };
  ninx = import ./default.nix { };

  # Create a script that evaluates the serialized code
  evalScript =
    code:
    let
      serialized = ninx.serialize code;
    in
    nixpkgs.runCommand "eval-result.json" 
      {
        requiredSystemFeatures = [ "recursive-nix" ];
        NIX_PATH = "nixpkgs=${<nixpkgs>}";
      }
      ''
        ${nixpkgs.nix}/bin/nix --extra-experimental-features nix-command eval --json --expr '${serialized}' > $out
      '';

  equals =
    expectedValue: code: expectedValue == (builtins.fromJSON (builtins.readFile (evalScript code)));
in

with ninx;

assert equals 7 (
  app (raw "builtins.add") [
    3
    4
  ]
);

assert equals {a=1;} {a=1;};

# assert equals 8 (
#   letin
#     { 
#       fib = func "n"
#
#     }
#     (var "fib" 6)
#   )
# ;

true
