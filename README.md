# ninx
> Nix in Nix

Nix expressions as a serializable data type in Nix

## Usage
ninx provides types for nix expressions via the Nixpkgs module system. You can use them like so:
```nix
{
  options.e = lib.mkOption {
    type = ninx.types.nix-expr; # TODO: nix format
  };
  config.e = { a = 1; };
}
```

Primitive values can be used as is. This includes:
- int
- float
- boolean
- string
- path
- null
- non-recursive attribute set
- list

Additionally, ninx provides ergnomic-ish helpers:
```nix
# variables
var "a"

# recursive attribute set
rec-set { a = var "b"; b.c = 2; } # rec { a = b; b.c = 2; }

# attribute access
# TODO: interpret string as variable; allow list of attrs
acc (var "a") "b.c.d"          # a.b.c.d

# operators
op.".or" (var "a") "b" 1       # a.b or 1
op."//" (var "a") { b = 2; }   # a // { b = 2; }

# conditionals
cond [
  ifthen false 1
  ifthen true 2
] 3
# if false
#   then 1
# else if true
#   then 2 
# else 3
# evaluates to 2

# let-ins
letin { a = 1; b.c = 2; } (var "b")   # evaluates to { c = 2; }
letin { x = (app (var "f") (var "x")); } (var "x")    # fix point! let x = f x; in x

# functions
lambda "x" (var "x")   # identity function, (x: x)
# you can also use attrset pattern in the argument: optional arguments, @-pattern and ...-pattern (varargs)
# below are equivalent to:
# ({ a ? 2, b, ... }@args: b)
lambda { a = 2; b = null; __at = "args"; __varargs= true; } (var "b")
lambda (args { a = 2; b = null; } "args" true) (var "b")

# function application
app (var "func") 1 # func 1

# import
importt ./default.nix

# lastly, string escape hatch
raw "<nixpkgs>"
raw ''
  builtins.trace "Hello world!" null
''
```

## Why?
Fair question. Why would you want to store encoded Nix code in Nix?

One usage I have is I want a flake templates repository like [this one](https://github.com/the-nix-way/dev-templates), but it is not DRY as it contains many `flake.nix` with similary setups.

My goal is to utilize this format to create a "flake-output" module, so that I can use it to target `flake-files` to generate `flake.nix`s, so I don't have to repeat myself. I know I am building an exosuit to open a pickle jar. But it's fun! I will update my progress here when I get to it.

If ~~you are as crazy as me~~ have found another use for ninx, please let me know!

## Status
- [x] Options/Types definitions
  - [x] Type checking behavior
  - [ ] Merging behavior (may need refactor away from submodules)
  - [ ] `with`, `assert`, `inherit`, comments: does anyone really need these?
- [x] Ergnomic helpers
- [x] Serialization
- [ ] Evaluation? (entirely possible, just tedious)

## Development
To run tests (in repo root):
```
nix eval --expr 'import ./tests {}' --impure --show-trace
```
