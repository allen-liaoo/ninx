{
  description = "Nix expressions as serializable data in Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    ninx-test-lib = import ./tests/_testLib.nix { nixpkgs = pkgs; };
  in
  {
    overlays.default = (final: prev: {
      formats = prev.formats //
        (let 
          ninx = import ./. { nixpkgs = final; };
        in {
          ninx = ninx.format;
        });
    });

    checks."x86_64-linux" = {
      tests = 
        let
          eval = ninx-test-lib.evalNix {
            src = ./.;
            entrypoint = "tests/default.nix";
            callArgs = ''
              {
                nixpkgsPath = "${nixpkgs.outPath}";
                nixpkgsArgs = { system = "${ system }"; };
                ninxPath = "${./.}";
              }
            '';
          };
        in
        pkgs.runCommand "check-tests" {} ''
          echo "=== result ==="
          cat ${eval.out}/result.json

          echo ""
          echo "=== error ==="
          cat ${eval.out}/error

          exit_code=$(cat ${eval.out}/exit-code)
          echo ""
          echo "=== exit code: $exit_code ==="

          if [ "$exit_code" = "0" ]; then
            touch $out
          else
            exit 1
          fi
        '';
    };
  };
}
