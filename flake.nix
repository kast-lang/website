{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    kast.url = "github:kast-lang/kast";
  };
  outputs = inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      kast = inputs.kast.packages.${system}.default;
    in
    {
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            zola
            (pkgs.writeShellScriptBin "kast" ''
              systemd-run --user --scope -p MemoryMax=10G \
                ${kast}/bin/kast "$@"
            '')
          ];
        };
      };
      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
