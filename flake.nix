
{
  description = "A simple flake for QBE";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;
      in
      {
        devShells.default = pkgs.mkShell {
          # nativeBuildInputs is for tools needed on the host to compile the program
          nativeBuildInputs = [
            pkgs.gcc
          ] ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.cctools
          ];

          shellHook = ''
            echo "Environment loaded for ${system}"
            ${lib.optionalString pkgs.stdenv.isDarwin "echo 'Darwin-specific cctools included.'"}
          '';
        };
      });
}
