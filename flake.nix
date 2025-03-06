{
  description = "A pristine single page web app example written in Haskell.";

  inputs =
  {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self , nixpkgs }:
  {
    devShells.x86_64-linux.default = with import nixpkgs { system = "x86_64-linux"; }; pkgs.mkShell
    {
      packages = with pkgs; [ haskell.compiler.ghc910 cabal-install ghcid ];
    };
  };
}
