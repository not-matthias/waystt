{
  description = "waystt - Wayland speech-to-text tool with stdout output";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        # Runtime dependencies
        runtimeDeps = with pkgs; [
          pipewire
          alsa-lib
          openssl
          stdenv.cc.cc.lib  # libstdc++.so.6 and other C++ runtime libs
        ];

        # Build-time dependencies
        nativeBuildInputs = with pkgs; [
          pkg-config
          rustToolchain
          llvmPackages.clang
          cmake
          git
        ];

        # Build dependencies
        buildInputs = with pkgs; [
          alsa-lib
          openssl
          pipewire
          llvmPackages.libclang.lib
        ];

      in
      {
        packages = {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "waystt";
            version = "0.3.1";

            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            inherit nativeBuildInputs buildInputs;

            # Set environment variables for build
            PKG_CONFIG_PATH = "${pkgs.lib.makeLibraryPath buildInputs}/pkgconfig";
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            # Ensure dynamic libraries are found at runtime
            postInstall = ''
              patchelf --set-rpath ${pkgs.lib.makeLibraryPath runtimeDeps} $out/bin/waystt
            '';

            meta = with pkgs.lib; {
              description = "Speech-to-text tool for Wayland with stdout output";
              homepage = "https://github.com/sevos/waystt";
              license = licenses.gpl3Plus;
              maintainers = [ ];
              platforms = platforms.linux;
            };
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          nativeBuildInputs = nativeBuildInputs ++ (with pkgs; [
            # Development tools
            cargo-watch
            cargo-edit

            # Optional runtime tools mentioned in README
            ydotool
            wl-clipboard

            # Debugging and testing
            ripgrep
            fd
            gh
          ]);

          # Environment variables for development
          RUST_BACKTRACE = "1";
          PKG_CONFIG_PATH = "${pkgs.lib.makeLibraryPath buildInputs}/pkgconfig";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeDeps;
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

          shellHook = ''
            echo "waystt development environment"
            echo "Rust version: $(rustc --version)"
            echo ""
            echo "Available commands:"
            echo "  cargo build         - Build the project"
            echo "  cargo run           - Run the project"
            echo "  cargo test          - Run tests"
            echo "  cargo watch         - Auto-rebuild on file changes"
            echo ""
            echo "Configuration:"
            echo "  Use --envfile .env to test with project-local config"
            echo "  Example: cargo run -- --envfile .env"
          '';
        };

        # Formatter for nix files
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
