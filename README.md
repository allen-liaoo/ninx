# ninx
> Nix in Nix

Store, merge, and serialize Nix expressions in Nix via the modules system.

## Why?
Fair question. Why would you want to store encoded Nix code in Nix?

One usage I have is: I want a flake templates repository like [this one](https://github.com/the-nix-way/dev-templates), but it is not DRY as it contains many `flake.nix` with similar setups.

My goal is to utilize ninx to create a "flake-output" module to target `flake-files` for generating `flake.nix` templates so I don't have to repeat myself. I know it's like building an exosuit to open a pickle jar. But it's fun! I will update my progress here when I get to it.

If you ~~are as crazy as me~~ have found other uses for ninx, please let me know!

## Usage
ninx provides types for nix expressions via the Nixpkgs module system. You can use them like so:
```nix
{ lib, ninx, ... }:
{
  options.e = lib.mkOption {
    type = ninx.types.expr;
  };
  config.e = ninx.letin { a = 1; } (ninx.var "a");
}
```

To use ninx, import this repo with the argument `{ nixpkgs = ...; }` (optional, defaults to `<nixpkgs>`), which outputs:
- Constructors for nix expressions (ergonomic helpers; more on this below)
- `types`: attribute set of nix expression types
- `format`: [nixpkgs format compliant](https://nixos.org/manual/nixos/stable/#sec-settings-nix-representable) attribute set; so you can replace `ninx.types.expr` above with `ninx.format.type`
- Utility functions (`serialize`, `getType`, etc.)

Alternatively, if you use flakes, use this repo's provided overlay output, `ninx.overlays.default`. For example, in your NixOS configuration:
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ninx.url    = "github:allen-liaoo/ninx"; # this repository
  };

  outputs = { nixpkgs, ninx, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.overlays = [ ninx.overlays.default ]; } # here
        ...
      ];
    };
  };
}
```
Then you can access the ninx format in `pkgs.formats.ninx`:
```nix
{ pkgs, lib, config, ... }:
let
  fmt = pkgs.formats.ninx { }; # empty args
in {
  options.gen-nix.content = lib.mkOption {
    type = fmt.type;
    default = { };
  };
  config.environment.etc."dir/generated-nix.nix".source =
    fmt.generate "generated-nix.nix" config.gen-nix.content;
}
```

## Constructing Nix Expressions
Many values can be used as is. This includes:
- int
- float
- boolean
- string
- path (note: relative paths are relative against wherever the nix-expr is serialized to)
- null
- non-recursive attribute set
- list

Additionally, ninx provides **ergnomic**-ish helpers:
```nix
inherit (ninx) # directly in scope:
  var recc op cond ifthen
  letin lambda args app importt raw;

# variables (type: var)
var "a"

# recursive attribute set (type: attrs)
recc { a = var "b"; b.c = 2; } # rec { a = b; b.c = 2; }

# operators (type: op)
op."." (var "a") "b"           # a.b
op.".or" (var "a") "b" 1       # a.b or 1
op."~" 1                       # - 1
op."//" (var "a") { b = 2; }   # a // { b = 2; }

# conditionals (type: conds)
cond [
  ifthen false 1
  ifthen true 2
] 3
/*
if false
  then 1
else if true
  then 2 
else 3
*/

# let-ins (type: let-in)
letin { a = 1; b.c = 2; } (var "b")   # evaluates to { c = 2; }
letin { x = (app (var "f") (var "x")); } (var "x")    # fixed point! let x = f x; in x

# functions (type: function)
lambda "x" (var "x")   # identity function, (x: x)
/*
you can also use attrset pattern in the argument:
optional arguments, @-pattern and ...-pattern (varargs)

below are equivalent to:
({ a ? 2, b, ... }@args: b)
*/
lambda { a = 2; b = null; __at = "args"; __varargs = true; } (var "b")
lambda (args { a = 2; b = null; } "args" true) (var "b")

# function application (type: application)
app (var "func") 1 # func 1

# import (type: import)
importt ./default.nix

# lastly, string escape hatch; not merge-friendly (type: raw)
raw "<nixpkgs>"
raw ''
  builtins.trace "Hello world!" null
''
```

Most expressions can be constructed directly as attrsets with special attributes prefixed by `__`. Read the [source](/default.nix) for more.

## Merge Behavior
Because expressions are types in the module system, they can be merged.
+ "Merges are allowed iff values are equal" are treu of these expressions:
  + Primitive values (except lists, non-recursive attribute sets)
  + Variables
  + Import
  + Raw
+ Lists are merged like `listOf` types.
+ Attribute sets (recursive or not) are merged like `attrsOf` types.
+ Conditionals: Conditions can be merged (like `listOf`), else case can be merged
+ Let-ins: bindings can be merged (like `attrsOf`), in clause can be merged
+ Functions: Argument (if attribute set) can be merged (like `attrsof`), functopn body can be merged
<!-- + WIP: Merging operator expressions and applications (in place list merging) -->

Merging works with functions like `mkForce`, `mkDefault`, `mkBefore`, `mkAfter` (also for conditionals or lists of nix exprs).

## Type Checking
Type checking in ninx involves checking the "type" of nix expressions, not the type of the value of nix expressions (the ordinary sense of the word "type"), which is a bit weird to think about. 

To see the name of the type, check the section on ergonomic helpers above. You can access the type via `ninxx.types.${name}`.

It is worth noting that all expressions with ergonomic helpers will type-check as attribute sets. That is because they are implemented as submodules. 

## Status
- [x] Options/Types definitions
  - [x] Type checking behavior
  - [x] Merging behavior
  - [ ] In-place list merging
  - [ ] `with`, `assert`, `inherit`, comments: does anyone really need these?
- [x] Ergnomic helpers
- [x] Serialization
  - [ ] Tests for serialization (string, not eval result)
- [x] Repo flake
  - [x] CI for tests
- [ ] Evaluation? (entirely possible, just tedious)
