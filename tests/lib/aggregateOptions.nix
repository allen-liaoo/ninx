{
  lib,
  ninx-lib,
  testEq,
  ...
}:

let
  inherit (lib)
    types
    mkOption;
  inherit (ninx-lib)
    aggregateOptions;

  aggregateOpts = m: 
    map
      (o: o.path)
      (aggregateOptions []
        m.options
      );
in

[
  (testEq "simple"
    [ ["simple"] ]
    (aggregateOpts {
      options.simple = mkOption {
        type = types.int;
      };
    }))

  (testEq "multiple"
    [ ["simple" ] [ "simple1"]  ]
    (aggregateOpts {
      options.simple = mkOption {
        type = types.int;
      };
      options.simple1 = mkOption {
        type = types.str;
        default = "a";
      };
    }))

  (testEq "submodules"
    [ ["simple" ] ]
    (aggregateOpts {
      options.simple = mkOption {
        type = types.submodule {};
      };
    }))

  (testEq "nested"
    [ ["simple" "op1" ] [ "simple" "op2" ] ]
    (aggregateOpts {
      options.simple.op1 = mkOption {
        type = types.int;
      };
      options.simple.op2 = mkOption {
        type = types.int;
        default = 0;
      };
    }))

]
