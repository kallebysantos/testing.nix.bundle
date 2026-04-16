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
    , flake-utils
    , crate2nix
    , ...
    }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        inherit (pkgs) lib;

      imports = [
        ./nix/rust-overlay/flake-module.nix
        ./nix/devshell/flake-module.nix
      ];
        # buildRustCrateForPkgs =
        #   crate:
        #   pkgs.buildRustCrate.override {
        #     rustc = pkgs.rust-bin.stable.latest.default;
        #     cargo = pkgs.rust-bin.stable.latest.default;
        #     defaultCrateOverrides = {
        #         hello = attrs: {
        #           nativeBuildInputs = [ pkgs.pkg-config ];
        #           buildInputs = [ pkgs.openblas ];
        #         };
        #       #                openblas-src = attrs: {
        #       #                  features = ["static"];
        #       #                  nativeBuildInputs = [ pkgs.pkg-config ];
        #       #                  buildInputs = [ pkgs.openblas ];
        #       #                };
        #       };
        #   };

        buildRustCrateForPkgs = pkgs:
          let
            # isBareMetal = pkgs.stdenv.hostPlatform.parsed.kernel.name == "none";
            # # Don't need other tools
            # stdenvBase = if isBareMetal then pkgs.stdenvNoCC else pkgs.stdenv;

            # stdenv =
            #   if stdenvBase.hostPlatform.extensions ? sharedLibrary
            #   then stdenvBase
            #   else
            #     lib.recursiveUpdate stdenvBase {
            #       # This is used in buildRustCrate. Should probably be optional there.
            #       hostPlatform.extensions.sharedLibrary = "";
            #     };

            fun = pkgs.buildRustCrate.override {
              # inherit stdenv;

              # Don't bother with cross compiler since we don't need stdlib
              inherit (pkgs.buildPackages.buildPackages) rustc cargo;
            };
          in
          args: fun (args // {
            nativeBuildInputs =  [ pkgs.pkg-config ];
            buildInputs = [ pkgs.openblas ];
            doCheck = false;
            release = true;
            RUSTFLAGS = "--cap-lints allow";
            extraRustcOpts = [ "--edition=2018" "-A" "rustdoc::all" "--cfg" "doc" ];
            cargoBuildFlags = [ "--lib" ];
          });

        generatedCargoNix = inputs.crate2nix.tools.${system}.generatedCargoNix {
          name = "hello";
          src = ./.;
        };

        # openblas = pkgs.openblas.stable.latest.default;
        cargoNix = import generatedCargoNix {
          inherit pkgs buildRustCrateForPkgs;
        };
        # cargoNix = generatedCargoNix;

      in
      rec {
        checks = {
          rustnix = cargoNix.rootCrate.build.override {
            runTests = true;
          };
        };

        packages = {
          # rustnix = cargoNix.rootCrate.build.override {
          #   crateOverrides = pkgs: pkgs.buildRustCrate.override {
          #     defaultCrateOverridess = {
          #       openblas-src = attrs: {
          #         featuresaaa = ["static"];
          #         nativeBuildInputs = [ pkgs.pkg-config ];
          #         buildInputs = [ pkgs.openblas ];
          #       };
          #     };
          #   };
          # };

          rustnix = cargoNix.rootCrate.build;
          default = packages.rustnix;

          inherit (pkgs) rust-toolchain;

          rust-toolchain-versions = pkgs.writeScriptBin "rust-toolchain-versions" ''
            ${pkgs.rust-toolchain}/bin/cargo --version
            ${pkgs.rust-toolchain}/bin/rustc --version
          '';
        };
      });
}
