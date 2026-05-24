{
  nixpkgs ? import <nixpkgs> { },
  lib ? nixpkgs.lib,
  ninx ? import ../default.nix { },
}:

let
  args = { inherit nixpkgs lib ninx; };
in
import ./serialize-eval.nix args
