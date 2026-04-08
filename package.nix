{
  lib,
  rustPlatform,
  openblas,
  pkg-config,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "nix-app";
  version = "0.1.0";
  src = ./.;
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openblas ];
  #OPENBLAS_NO_VENDOR = 1;
  # tell blas-src to use system openblas via pkg-config
  #CARGO_FEATURE_OPENBLAS = "1";
  meta = {
    description = "My Rust CLI";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
})
