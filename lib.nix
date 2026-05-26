{
  nixpkgs ? import <nixpkgs> { },
  lib ? nixpkgs.lib,
  ...
}:

let
  inherit (builtins)
    all
    ;

  inherit (lib)
    types
    filter
    pipe
    concatMap
    foldlAttrs
    ;

  # collect options of a modules options set
  # returns list of { path, val }
  aggregateOptions =
    pathPrefix:
    foldlAttrs (
      paths: name: val:
      let
        curPath = pathPrefix ++ [ name ];
      in
      if val ? _type && val._type == "option" then
        paths
        ++ [
          {
            path = curPath;
            inherit val;
          }
        ]
      else
        paths ++ aggregateOptions curPath val
    ) [ ];

  # a submodule which checks that each option with no default value exists
  submoduleWithAttrCheck =
    module:
    let
      subm = types.submodule module;
      modules = subm.functor.payload.modules;
      optionsLst = map (m: m.options or { }) modules;
      options = map (aggregateOptions [ ]) optionsLst;
      attrPaths = pipe options [
        (concatMap (_: _))
        (filter (o: !(o.val ? default)))
        (map (o: o.path))
      ];
    in
    types.addCheck subm (x: all (p: lib.hasAttrByPath p x) attrPaths);
in
{
  inherit
    aggregateOptions
    submoduleWithAttrCheck
    ;
}
