{
  lib,
  ninx-lib,
  test,
  ...
}:

let
  inherit (lib)
    types
    mkOption
    ;
  inherit (ninx-lib)
    submoduleWithAttrCheck
    ;
in

[
  (test "required-present" (
    (submoduleWithAttrCheck {
      options.required = mkOption {
        type = types.int;
      };
    }).check
      { required = 1; }
  ))

  (test "required-absent" (
    !(
      (submoduleWithAttrCheck {
        options.required = mkOption {
          type = types.int;
        };
      }).check
      { }
    )
  ))

  (test "optional-present" (
    (submoduleWithAttrCheck {
      options.optional = mkOption {
        type = types.int;
        default = 0;
      };
    }).check
      { optional = 1; }
  ))

  (test "optional-absent" (
    (submoduleWithAttrCheck {
      options.optional = mkOption {
        type = types.int;
        default = 0;
      };
    }).check
      { }
  ))

  (test "required-optional-succeed" (
    (submoduleWithAttrCheck {
      options.required = mkOption {
        type = types.int;
      };
      options.optional = mkOption {
        type = types.int;
        default = 0;
      };
    }).check
      { required = 0; }
  ))

  (test "required-optional-fail" (
    !(
      (submoduleWithAttrCheck {
        options.required = mkOption {
          type = types.int;
        };
        options.optional = mkOption {
          type = types.int;
          default = 0;
        };
      }).check
      { optional = 0; }
    )
  ))

  (test "submodule" (
    (submoduleWithAttrCheck {
      options.required = mkOption {
        type = types.submodule {
          options.a = lib.submodule { };
        };
      };
    }).check
      {
        required = {
          a = { };
        };
      }
  ))
]
