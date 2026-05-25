{
  nixpkgs ? import <nixpkgs> { },
  lib ? nixpkgs.lib,
  ...
}:

let
  ninx-lib = import ./lib.nix { inherit nixpkgs lib; };

  inherit (builtins)
    attrNames
    all
    head
    tail
    hasAttr
    isAttrs
    isList
    isString
    ;

  inherit (lib)
    types
    pipe
    findFirst
    genAttrs
    concatStrings
    concatStringsSep
    mapAttrsToList
    mkOption
    ;

  inherit (ninx-lib)
    submoduleWithAttrCheck;

  # Ergonomic Nix expressions
  var = __var: { inherit __var; };
  rec-set = a: { __rec = true; } // a;
  acc = __set: __path: {
    inherit __set __path;
  };
  op = genAttrs (attrNames ops) (
    __op: __args: {
      inherit __op __args;
    }
  );
  conds = __conds: __else: {
    inherit __conds __else;
  };
  ifthen = __if: __then: {
    inherit __if __then;
  };
  letin = __let: __in: {
    inherit __let __in;
  };
  lambda = __arg: __body: {
    inherit __arg __body;
  };
  args = attrs: __at: __varargs: attrs // { # when function argument is an attrset pattern
    inherit __at __varargs;
  };
  app = f: as: {
    __app =
      if isList as then
        [ f ] ++ as
      else
        [
          f
          as
        ];
  };
  importt = __import: { inherit __import; };
  raw = __raw: { inherit __raw; };

  # Nix expression types
  nix-expr = types.oneOf [
      nix-prim
      nix-var
      nix-access
      nix-op
      nix-conds
      nix-let-in
      nix-function
      nix-application
      nix-import
      nix-raw
      nix-attrs 
      # order matters
      # since nix-attrs is free-form, we need it to be the last so attrset matching previous types will be used first
  ];

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

  nix-var = submoduleWithAttrCheck {
    options = {
      __var = mkOption {
        type = types.str;
      };
    };
  };
  specialAttrs.var = [ "__var" ];

  nix-attrs = submoduleWithAttrCheck {
    freeformType = types.attrsOf nix-expr;
    options = {
      __rec = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };
  specialAttrs.attrs = [ "__rec" ];

  nix-access = submoduleWithAttrCheck {
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

  ops = {
    # may be useful in the future if we eval
    "." = set: path: set.${path};
    ".or" =
      set: path: _or:
      set.${path} or _or;
    "+" = e1: e2: e1 + e2;
    "-" = n1: n2: n1 - n2;
    "*" = n1: n2: n1 * n2;
    "/" = n1: n2: n1 / n2;
    "!" = n: !n;
    "//" = set: new: set // new;
    "<" = e1: e2: e1 < e2;
    ">" = e1: e2: e1 > e2;
    "<=" = e1: e2: e1 <= e2;
    ">=" = e1: e2: e1 >= e2;
    "==" = e1: e2: e1 == e2;
    "!=" = e1: e2: e1 != e2;
    "&&" = e1: e2: e1 && e2;
    "||" = e1: e2: e1 || e2;
    "->" = e1: e2: !e1 || e2;
    "|>" = e1: e2: e2 e1;
    "<|" = e1: e2: e1 e2;
  };
  nix-op = submoduleWithAttrCheck {
    options = {
      __op = mkOption {
        type = types.enum (attrNames ops);
      };
      __args = mkOption {
        type = types.listOf nix-expr;
      };
    };
  };
  specialAttrs.op = [
    "__op"
    "__args"
  ];

  nix-let-in = submoduleWithAttrCheck {
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

  nix-conds = submoduleWithAttrCheck {
    options = {
      __conds = mkOption {
        type =
          with types;
          listOf submoduleWithAttrCheck {
            __if = mkOption {
              type = nix-expr;
            };
            __then = mkOption {
              type = nix-expr;
            };
          };
      };
      __else = mkOption {
        type = nix-expr;
      };
    };
  };
  specialAttrs.conds = [
    "__conds"
    "__else"
  ];
  specialAttrs.cond = [
    "__if"
    "__then"
  ];

  nix-function = submoduleWithAttrCheck {
    options = {
      __arg =
        let
          argsSet = submoduleWithAttrCheck {
            freeformType = types.attrsOf nix-expr; # if null, treat as nonoptional
            options = {
              # @-pattern
              __at = mkOption {
                type = types.str;
                default = null;
              };
              # ... pattern
              __varargs = mkOption {
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

  nix-application = submoduleWithAttrCheck {
    options = {
      __app = mkOption {
        type = types.listOf nix-expr;
      };
    };
  };
  specialAttrs.application = [ "__app" ];

  nix-import = submoduleWithAttrCheck {
    options = {
      __import = mkOption {
        type = nix-expr;
      };
    };
  };
  specialAttrs.import = [ "__import" ];

  nix-raw = submoduleWithAttrCheck {
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
      findFirst (t: all (attr: hasAttr attr e) specialAttrs.${t}) "attrs" (attrNames specialAttrs)
    else
      "prim";

  # Nix expression to string
  serialize = {
    __functor = self: e: self.${getType e} e;

    prim =
      e:
      if isString e then
        ''"${e}"''
      else if e == true then
        "true"
      else if e == false then
        "false"
      else
        toString e;

    var = e: e.__var;

    bindings =
      e:
      "${
        (pipe e [
          (mapAttrsToList (
            k: v: ''
              ${k} = ${serialize v};
            ''
          ))
          concatStrings
        ])
      }";

    attrs =
      e: (if e ? __rec && e.__rec then "rec " else "") + "{" + serialize.bindings (strip "attrs" e) + "}";

    access = e: "${serialize e.__set}.${e.__path}";

    op =
      e:
      let
        fst = serialize (head e.__args);
        snd = serialize (head (tail e.__args));
        trd = serialize (head (head (tail e.__args)));
      in
      "(${
        concatStrings (
          if e.__op == ".or" then
            [
              fst
              "."
              snd
              "or"
              trd
            ]
          else if e.__op == "." then
            [
              fst
              "."
              snd
            ]
          else if e.__op == "!" then
            [
              e.__op
              " "
              fst
            ]
          else
            [
              fst
              " "
              e.__op
              " "
              snd
            ]
        )
      })";

    cond = c: ''
      if ${serialize c.__if} then ${serialize c.__then}
    '';

    conds =
      e:
      let
        fst = head e.__conds;
        rst = tail e.__conds;
      in
      ''
        (
          ${serialize.cond fst}
          ${concatStringsSep "\n" (map (c: "else " + serialize.cond c) rst)}
          else ${serialize e.__else}
        )
      '';

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
        let
          func = head e.__app;
        in
        if isString func then # treat as function
          func
          + " "
          + pipe (tail e.__app) [
            (map serialize)
            (concatStringsSep " ")
          ]
        else
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
    rec-set
    acc
    op
    conds
    ifthen
    letin
    lambda
    args
    app
    importt
    raw
    serialize
    getType
    ;
  types = {
    inherit
      nix-expr
      nix-prim
      nix-var
      nix-attrs 
      nix-access
      nix-op
      nix-conds
      nix-let-in
      nix-function
      nix-application
      nix-import
      nix-raw
      ;
  };
}
