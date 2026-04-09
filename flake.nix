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

        # Map Nix system strings to QBE default targets (mirrors the Makefile's uname logic)
        deftgt =
          if system == "aarch64-darwin" then "T_arm64_apple"
          else if system == "x86_64-darwin" then "T_amd64_apple"
          else if system == "aarch64-linux" then "T_arm64"
          else if system == "riscv64-linux" then "T_rv64"
          else "T_amd64_sysv";

        cc = if pkgs.stdenv.isDarwin then pkgs.clang else pkgs.gcc;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "qbe";
          version = "1.2";
          src = ./.;

          nativeBuildInputs = [ cc ] ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.cctools
          ];

          # Generate config.h from the known system rather than running uname
          # (uname is not available / unreliable inside the Nix sandbox).
          preBuild = ''
            echo "#define Deftgt ${deftgt}" > config.h
          '';

          makeFlags = [ "CC=${cc.targetPrefix}cc" ];

          installPhase = ''
            mkdir -p $out/bin
            install -m755 qbe $out/bin/qbe
          '';
        };

        devShells.default = pkgs.mkShell {
          # nativeBuildInputs is for tools needed on the host to compile the program
          nativeBuildInputs = [ cc ] ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.cctools
          ];

          shellHook = ''
            echo "Environment loaded for ${system}"
            ${lib.optionalString pkgs.stdenv.isDarwin "echo 'Darwin-specific cctools included.'"}
          '';
        };
      });
}
