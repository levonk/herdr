{
  description = "herdr - terminal workspace manager for AI coding agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.15.2";
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "herdr";
          version = "0.5.10";
          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.cctools
            pkgs.fixDarwinDylibNames
            pkgs.xcbuild
          ];

          preBuild = ''
            mkdir -p $TMPDIR/zig-wrapper
            cat > $TMPDIR/zig-wrapper/zig <<'EOF'
            #!/usr/bin/env bash
            args=("$@")
            # If building libghostty-vt on Darwin, disable xcframework
            if [[ "$1" == "build" && " ''${args[*]}" == *"-Demit-lib-vt"* ]]; then
              args+=("-Demit-xcframework=false")
            fi
            exec ${zig}/bin/zig "''${args[@]}"
            EOF
            chmod +x $TMPDIR/zig-wrapper/zig
            export PATH="$TMPDIR/zig-wrapper:$PATH"
            export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
          '';

          # Integration tests require PTY, sockets, and runtime dirs unavailable in sandbox.
          doCheck = false;

          meta = with pkgs.lib; {
            description = "Terminal workspace manager for AI coding agents";
            homepage = "https://herdr.dev";
            license = licenses.agpl3Plus;
            mainProgram = "herdr";
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/herdr";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            rustfmt
            clippy
            zig
            just
          ];
        };
      });
}
