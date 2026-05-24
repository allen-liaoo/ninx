{
  nixpkgs ? import <nixpkgs> { },
  lib ? nixpkgs.lib,
  ...
}:

let
  inherit (builtins)
    attrNames
    attrValues
    all
    hasAttr
    isAttrs
    isString
    ;

  inherit (lib)
    types
    pipe
    findFirst
    concatStrings
    concatStringsSep
    mapAttrsToList
    mkOption
    ;

  # Ergonomic Nix expressions
  var = s: { __var = s; };
  recc = a: { __rec = true; } // a;
  acc = s: p: {
    __set = s;
    __path = p;
  };
  letin = l: i: {
    __let = l;
    __in = i;
  };
  func = f: a: {
    __arg = f;
    __body = a;
  };
  app = f: as: { __app = [ f ] ++ as; };
  import = f: { __import = f; };
  raw = r: { __raw = r; };

  # Nix expression types
  nix-types = {
    inherit
      nix-prim
      nix-var
      nix-attrs
      nix-access
      nix-let-in
      nix-function
      nix-application
      nix-import
      nix-raw
      ;
  };

  nix-expr = types.oneOf (attrValues nix-types);

  nix-prim = types.nullOr (
    with types;
    oneOf [
      bool
      int
      float
      str
      path
    ]
  );

  nix-var = types.submodule {
    options = {
      __var = mkOption {
        type = types.str;
      };
    };
  };
  specialAttrs.var = [ "__var" ];

  nix-attrs = types.submodule {
    freeformType = types.attrsOf nix-expr;
    options = {
      __rec = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };
  specialAttrs.attrs = [ "__rec" ];

  nix-access = types.submodule {
    options = {
      __set = mkOption {
        type = nix-expr;
      };
      __path = mkOption {
        type = types.separatedString ".";
      };
    };
  };
  specialAttrs.access = [
    "__set"
    "__path"
  ];

  nix-let-in = types.submodule {
    options = {
      __let = mkOption {
        type = types.attrsOf nix-expr;
      };
      __in = mkOption {
        type = nix-expr;
      };
    };
  };
  specialAttrs.let-in = [
    "__let"
    "__in"
  ];

  # TODO: ite

  nix-function = types.submodule {
    options = {
      __arg =
        let
          argsSet = types.submodule {
            freeformType = types.attrsOf nix-expr; # if null, treat as nonoptional
            options = {
              __at = mkOption {
                # @-pattern
                type = types.str;
              };
              __varargs = mkOption {
                # ... pattern
                type = types.bool;
                default = false; # TODO: add check
              };
            };
          };
        in
        mkOption {
          type = with types; either str (either (submodule argsSet));
        };
      __body = mkOption {
        type = nix-expr;
      };
    };
  };
  specialAttrs.function = [
    "__arg"
    "__body"
  ];
  specialAttrs.function-arg = [
    "__at"
    "__varargs"
  ];

  nix-application = types.submodule {
    options = {
      __app = mkOption {
        type = types.listOf nix-expr;
      };
    };
  };
  specialAttrs.application = [ "__app" ];

  nix-import = types.submodule {
    options = {
      __import = mkOption {
        type = nix-expr;
      };
    };
  };
  specialAttrs.import = [ "__import" ];

  nix-raw = types.submodule {
    options = {
      __raw = mkOption {
        type = types.str;
      };
    };
  };
  specialAttrs.raw = [ "__raw" ];

  # Utilities
  strip = t: e: removeAttrs e specialAttrs.${t};

  getType =
    e:
    if isAttrs e then
      findFirst (t: all (attr: hasAttr attr e) specialAttrs.${t}) "attrs" (
        attrNames specialAttrs
      )
    else
      "prim";

  # Nix expression to string
  serialize = {
    __functor = self: e: self.${getType e} e;

    prim = e: if isString e then ''"${e}"'' else toString e;

    var = e: e.__var;

    bindings =
      e:
      "{${
        (pipe e [
          (mapAttrsToList (
            k: v: ''
              ${k} = ${serialize v};
            ''
          ))
          concatStrings
        ])
      }}";

    attrs = e: (if e ? __rec && e.__rec then "rec " else "") + serialize.bindings (strip "attrs" e);

    access = e: "${serialize e.__set}.${e.__path}";

    let-in = e: ''
      let
        ${serialize.bindings e.__let}
      in
        ${serialize e.__in}
    '';

    function = e: ''
      (
        ${
          if isString e.__arg then
            e.__arg
          else
            (pipe (strip "function" e.__arg) [
              (mapAttrsToList (
                k: v: ''
                  ${k}${if isNull v then "" else " ? " + serialize v},;
                ''
              ))
            ])
        }:
        ${serialize e.__body}
      )
    '';

    application =
      e:
      "(${
        pipe e.__app [
          (map serialize)
          (concatStringsSep " ")
        ]
      })";

    import = e: "import ${serialize e.__import}";

    raw = e: e.__raw;
  };

in
{
  inherit
    var
    recc
    acc
    letin
    func
    app
    import
    raw
    serialize
    getType
    ;
  types = nix-types // {
    inherit nix-expr;
  };
}
