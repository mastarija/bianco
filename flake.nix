{
  description = "A pristine single page web app example written in Haskell.";

  inputs =
  {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    ghcjs.url = "git+https://gitlab.haskell.org/ghc/ghc.nix#js-cross";
  };

  outputs = { self , nixpkgs , ghcjs }:
  {
    devShells.x86_64-linux.default = with import nixpkgs { system = "x86_64-linux"; }; pkgs.mkShell
    {
      packages = with pkgs; [ haskell.compiler.ghc910 cabal-install ghcid ghcjs ];
    };
  };
}
