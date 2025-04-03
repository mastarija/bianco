{
  description = "A pristine single page web app example written in Haskell.";

  inputs =
  {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self , nixpkgs , flake-utils } : flake-utils.lib.eachDefaultSystem
  ( system :
    {
      devShells.default = with import nixpkgs { inherit system; }; with pkgs;
      let
        ghc-nt = haskell.compiler.ghc912;
        ghc-js = haskell.compiler.ghc912.override
        {
          stdenv = stdenv.override { targetPlatform = pkgsCross.ghcjs.stdenv.targetPlatform; };
        };
      in
        mkShell
        {
          packages = [ ghc-nt ghc-js cabal-install ghcid emscripten ];
          shellHook =
          ''
            if [ ! -d $(pwd)/.emscripten_cache ]; then
              cp -R ${emscripten}/share/emscripten/cache/ $(pwd)/.emscripten_cache
              chmod u+rwX -R $(pwd)/.emscripten_cache
              export EM_CACHE=$(pwd)/.emscripten_cache
            fi

            alias ghc-js=javascript-unknown-ghcjs-ghc
          '';
        };
    }
  );
}
