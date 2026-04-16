{
  description = "Rust-Nix";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix.url = "github:nix-community/crate2nix";

    # Development

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-public-keys = "eigenvalue.cachix.org-1:ykerQDDa55PGxU25CETy9wF6uVDpadGGXYrFNJA3TUs=";
    extra-substituters = "https://eigenvalue.cachix.org";
    allow-import-from-derivation = true;
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , flake-parts
    , rust-overlay
    , crate2nix
    , ...
    }: flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # imports = [
      #   ./nix/rust-overlay/flake-module.nix
      #   ./nix/devshell/flake-module.nix
      # ];

      perSystem = { system, lib, inputs', ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };

          buildRustCrateForPkgs =
            crate:
            pkgs.buildRustCrate.override {
              rustc = pkgs.rust-bin.stable.latest.default;
              cargo = pkgs.rust-bin.stable.latest.default;
            };

          generatedCargoNix = inputs.crate2nix.tools.${system}.generatedCargoNix {
            name = "nix-app";
            src = ./.;
          };

          # openblas = pkgs.openblas.stable.latest.default;
          cargoNix = import generatedCargoNix {
            inherit pkgs buildRustCrateForPkgs;
          };

          # rootCrate = cargoNix.rootCrate.build.override {
          #   crateOverrides = pkgs: pkgs.buildRustCrate.override {
          #     # defaultCrateOverrides = {
          #     #   openblas-src  = attrs: {
          #     #     features = ["static"];
          #     #     # buildInputs = [ openblas brew ];
          #     #   };
          #     # };
          #   };
          # };
        in
        rec {
          checks = {
            rustnix = cargoNix.rootCrate.build.override {
              runTests = true;
            };
          };

          packages = {
            rustnix = cargoNix.rootCrate.build.override {
              crateOverrides = pkgs: pkgs.buildRustCrate.override {
                defaultCrateOverrides = pkgs.defaultCrateOverrides //{
                  # git2 = attrs: {
                  #   buildInputs = [ pkgs.openssl ];
                  # };
                  blas-src = attrs: {
                    #features = ["static"];
                    buildInputs = [ pkgs.openblas ];
                  };
                };
              };
            };

            default = packages.rustnix;

            inherit (pkgs) rust-toolchain;

            rust-toolchain-versions = pkgs.writeScriptBin "rust-toolchain-versions" ''
              ${pkgs.rust-toolchain}/bin/cargo --version
              ${pkgs.rust-toolchain}/bin/rustc --version
            '';
          };
        };
    };
}
