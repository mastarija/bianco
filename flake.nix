{
  description = "A pristine single page web app example written in Haskell.";

  inputs =
  {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self , nixpkgs }:
  {
    devShells.x86_64-linux.default = with import nixpkgs { system = "x86_64-linux"; }; with pkgs;
    let
      ghc = haskell.compiler.ghc9101;
      ghc-js = haskell.compiler.ghc9101.override
      {
        stdenv = stdenv.override { targetPlatform = pkgsCross.ghcjs.stdenv.targetPlatform; };
      };
    in
      mkShell
      {
        packages = [ ghc ghc-js cabal-install ghcid emscripten ];
        shellHook = ''
          alias ghc-js=javascript-unknown-ghcjs-ghc

          if [ ! -d $(pwd)/.emscripten_cache ]; then
            cp -R ${emscripten}/share/emscripten/cache/ $(pwd)/.emscripten_cache
            chmod u+rwX -R $(pwd)/.emscripten_cache
            export EM_CACHE=$(pwd)/.emscripten_cache
          fi
        '';
      };
  };
}
