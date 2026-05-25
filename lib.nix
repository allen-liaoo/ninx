
{
  nixpkgs ? import <nixpkgs> {},
  lib ? nixpkgs.lib,
  ...
}:

let
  inherit (builtins)
    all;

  inherit (lib)
    types
    filter
    pipe
    concatMap
    foldlAttrs;

  evalNixStr = expr:
    let
      script =
        nixpkgs.runCommand "eval-result.json"
          {
            requiredSystemFeatures = [ "recursive-nix" ];
            NIX_PATH = "nixpkgs=${<nixpkgs>}";
          }
          ''
            ${nixpkgs.nix}/bin/nix --extra-experimental-features nix-command eval --json --show-trace --expr '${expr}' > $out
          '';
    in
    (builtins.fromJSON (builtins.readFile script));

  # collect options of a modules options set
  # returns list of { path, val }
  aggregateOptions = pathPrefix:
    foldlAttrs
      (paths: name: val:
        let
          curPath = pathPrefix ++ [ name ];
        in
        if val ? _type && val._type == "option" then 
          paths ++ [{ path = curPath; inherit val; }]
        else
          paths ++ aggregateOptions curPath val
      )
      [ ]
      ;

  # a submodule which checks that each option with no default value exists
  submoduleWithAttrCheck = module:
    let
      subm = types.submodule module;
      modules = subm.functor.payload.modules;
      optionsLst = map (m: m.options or { }) modules;
      options = map (aggregateOptions []) optionsLst;
      attrPaths = pipe options [
        (concatMap (_: _))
        (filter (o: !(o.val ? default)))
        (map (o: o.path))
      ];
    in
    types.addCheck
      subm
      (x: all (p: lib.hasAttrByPath p x) attrPaths);
in
{
  inherit
    evalNixStr
    aggregateOptions
    submoduleWithAttrCheck;
}
