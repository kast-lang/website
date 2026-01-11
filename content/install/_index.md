+++
title = "Install Kast"
+++

# Install Kast

**NOTE** This is very alpha

## Online Playground

You can try Kast in browser:

<https://play.kast-lang.org>

## Linux

Download <https://builds.kast-lang.org/kast-linux.tar.gz>

```sh
tar xzf kast-linux.tar.gz
./bin/kast
```

## MacOS

Download <https://builds.kast-lang.org/kast-macos.tar.gz>

```sh
tar xzf kast-macos.tar.gz
./bin/kast
```

## Windows

**TODO**

## Nix Flakes

Run directly: `nix run github:kast-lang/kast`
Enter temp shell with kast installed: `nix shell github:kast-lang/kast`

An example flake providing a devShell with kast installed (for `nix develop`):

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs";
    kast.url = "github:kast-lang/kast";
  };
  outputs = { kast, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = [
            kast.packages.${system}.kast
          ];
        };
      };
    };
}
```
