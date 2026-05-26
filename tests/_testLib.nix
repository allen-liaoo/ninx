
{
  nixpkgs,
  ninx,
}:

let
  lib = nixpkgs.lib;
in
rec {
  # nix value to nix string
  toString = v: 
    # dont serialize nix-types submodules to nix code; keep as attrs
    if builtins.isAttrs v then attrsToString v
    # if list, cant use builtin (format not right for nix) and cant use serialize (will serialize elems)
    else if builtins.isList v then "[" + lib.concatStringsSep " " (map toString v) + "]" 
    # serialize prim types
    else ninx.serialize.prim v;

  # attrset to nix string; does not support recursive sets
  attrsToString = attr: 
    "{" + lib.pipe attr [
      (lib.mapAttrsToList (
        k: v: ''
          ${k} = ${toString v};
        ''
      ))
      lib.concatStrings
    ] + "}";
  #"{" + serialize.bindings (strip "attrs" e) + "}";


  # Evaluates a nix code string, returns result or error; build never fails
  evalNixStr =
    {
      args ? [
        "--json"
        "--show-trace"
        "--impure"
      ],
      name ? "eval",
      expr,
    }:
    let
      args' = lib.concatStringsSep " " args;
      script =
        nixpkgs.runCommand name
          {
            requiredSystemFeatures = [ "recursive-nix" ];
          }
          ''
            mkdir -p "$out"

            if ${nixpkgs.nix}/bin/nix \
              --extra-experimental-features nix-command \
              eval ${args'} \
              --expr '${expr}' \
              > "$out/result.json" \
              2> "$out/error"
            then
              echo 0 > "$out/exit-code"
            else
              echo $? > "$out/exit-code"
            fi

            exit 0
          '';
    in
    {
      success = 0 == lib.toInt (builtins.readFile "${script}/exit-code");
      result = builtins.fromJSON (builtins.readFile "${script}/result.json");
      error = builtins.readFile "${script}/error";
    };
}
