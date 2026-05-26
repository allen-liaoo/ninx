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
    fix
    findFirst
    genAttrs
    concatStrings
    concatStringsSep
    mapAttrsToList
    mkOption
    ;

  inherit (ninx-lib)
    submoduleWithAttrCheck
    ;

  # Ergonomic Nix expressions
  ergo = {
    var = __var: { inherit __var; };
    recc = a: { __rec = true; } // a;
    # function that takes n-args for n-arity operator
    op = genAttrs (attrNames ops) (
      __op:
      let
        mkFunc =
          arity: __args:
          if arity == 0 then { inherit __op __args; } else (arg: mkFunc (arity - 1) (__args ++ [ arg ]));
        arity = ops.${__op};
      in
      mkFunc arity [ ]
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
    args =
      attrs: __at: __varargs:
      attrs
      // {
        # when function argument is an attrset pattern
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
  };

  # Nix expression types

  # nix-types lookup order
  # since nix-attrs is free-form, we need it to be the last so attrset matching previous types will be used first
  nix-types-ord = [
    "prim"
    "var"
    "op"
    "conds"
    "let-in"
    "function"
    "application"
    "import"
    "raw"
    "attrs" # last
  ];

  getType =
    e: if isAttrs e then findFirst (t: nix-types.${t}.check e) "attrs" nix-types-ord else "prim";

  nix-types = fix (self: {
    expr = #types.addCheck
      (types.oneOf (map (t: self.${t}) nix-types-ord))
      #(x: true)
      // { description = "nix expression"; }; # required to avoid inf rec as descriptions are eagerly evaled

    prim = (types.nullOr (
      with types;
      oneOf [
        bool
        int
        float
        str
        path
        (listOf self.expr)
      ]
    )) // { description = "nix primitive"; };

    var = (submoduleWithAttrCheck {
      options = {
        __var = mkOption {
          type = types.uniq types.str;
        };
      };
    }) // { description = "nix variable"; };

    attrs = submoduleWithAttrCheck {
      freeformType = types.attrsOf self.expr;
      options = {
        __rec = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };

    op = (submoduleWithAttrCheck {
      options = {
        __op = mkOption {
          type = types.enum (attrNames ops);
        };
        __args = mkOption {
          type = types.uniq (types.listOf self.expr);
        };
      };
    }) // { description = "nix operator expression"; };

    let-in = (submoduleWithAttrCheck {
      options = {
        __let = mkOption {
          type = types.attrsOf self.expr;
        };
        __in = mkOption {
          type = self.expr;
        };
      };
    }) // { description = "nix let-in"; };

    conds = (submoduleWithAttrCheck {
      options = {
        __conds = mkOption {
          type =
            with types;
            listOf submoduleWithAttrCheck {
              __if = mkOption {
                type = self.expr;
              };
              __then = mkOption {
                type = self.expr;
              };
            };
        };
        __else = mkOption {
          type = self.expr;
        };
      };
    }) // { description = "nix conditional"; };

    function = (submoduleWithAttrCheck {
      options = {
        __arg =
          let
            argsSet = submoduleWithAttrCheck {
              freeformType = types.attrsOf self.expr; # if null, treat as nonoptional
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
          type = self.expr;
        };
      };
    }) // { description = "nix lambda"; };

    application = (submoduleWithAttrCheck {
      options = {
        __app = mkOption {
          type = types.uniq (types.listOf self.expr);
        };
      };
    }) // { description = "nix function call"; };

    import = (submoduleWithAttrCheck {
      options = {
        __import = mkOption {
          type = types.uniq self.expr;
        };
      };
    }) // { description = "nix import"; };

    raw = (submoduleWithAttrCheck {
      options = {
        __raw = mkOption {
          type = types.str;
        };
      };
    }) // { description = "raw nix expression"; };

  });

  # Utilities
  specialAttrs.attrs = [ "__rec" ];
  specialAttrs.function-arg = [
    "__at"
    "__varargs"
  ];
  strip = t: e: removeAttrs e specialAttrs.${t};

  # operator and their arity
  ops = {
    "." = 2;
    ".or" = 3;
    "+" = 2;
    "-" = 2;
    "~" = 1; # negative
    "*" = 2;
    "/" = 2;
    "!" = 1;
    "//" = 2;
    "<" = 2;
    ">" = 2;
    "<=" = 2;
    ">=" = 2;
    "==" = 2;
    "!=" = 2;
    "&&" = 2;
    "||" = 2;
    "->" = 2;
    "|>" = 2;
    "<|" = 2;
  };

  # Nix expression to string
  serialize = {
    __functor = self: e: self.${getType e} e;

    prim = {
      __functor = self: e: self.${builtins.typeOf e} e;
      null = _: "null";
      bool = e: if e == true then "true" else "false";
      int = toString;
      float = toString;
      string = e: ''"${e}"'';
      path = toString;
      list = e: "[" + concatStringsSep " " (map serialize e) + "]";
    };

    var = e: e.__var;

    bindings =
      e:
      (pipe e [
        (mapAttrsToList (
          k: v: ''
            ${k} = ${serialize v};
          ''
        ))
        concatStrings
      ]);

    attrs =
      e: (if e ? __rec && e.__rec then "rec " else "") + "{" + serialize.bindings (strip "attrs" e) + "}";

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
          else if e.__op == "!" || e.__op == "~" then
            [
              (if e.__op == "~" then "-" else e.__op)
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
            (pipe (strip "function-arg" e.__arg) [
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
ergo
// {
  inherit
    serialize
    getType
    ;
  types = nix-types;
}
