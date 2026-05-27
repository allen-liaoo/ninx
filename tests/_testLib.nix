
{
  nixpkgs,
  ninx ? null,
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

  # Evaluate nix code, return result or error; build never fails
  evalNix =
    {
      nixArgs ? [
        "--json"
        "--show-trace"
        "--impure"
      ],
      name ? "eval",
      expr ? null, # expression string to evaluate
      src ? null,  # src directory of file to evaluate
      entrypoint ? "default.nix",  # used when src is given
      callArgs ? null, # call expr or imported entrypoint with string args
      drvArgs ? { },   # args to pass into derivation
    }:
    assert (src == null) != (expr == null);  # exactly one required
    let
      nixArgs' = lib.concatStringsSep " " nixArgs;
      script =
        nixpkgs.runCommand name
          (
            {
              requiredSystemFeatures = [ "recursive-nix" ];
              nativeBuildInputs = [ nixpkgs.nix ];
            }
            // lib.optionalAttrs (src != null) { inherit src; }
            // drvArgs
          )
          ''
            mkdir -p "$out"

            ${if expr != null then ''
              cat > eval.nix << 'EOF'
              ${expr}
              EOF
              target=./eval.nix
            '' else ''
              cp -r "$src" ./src
              chmod -R u+w ./src
              target=./src/${entrypoint}
            ''}

            # Store call args in file so we don't have to escape quotes and the likes
            ${if callArgs != null then ''
              cat > callargs.nix << 'EOF_CALLARGS'
              ${callArgs}
              EOF_CALLARGS
            '' else ""}

            ${if callArgs != null then ''
              evalExpr="(import $target) (import ./callargs.nix)"
            '' else ''
              evalExpr="import $target"
            ''}

            if nix \
              --extra-experimental-features nix-command \
              eval ${nixArgs'} \
              --expr "$evalExpr" \
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
      out = script;
    };
}
