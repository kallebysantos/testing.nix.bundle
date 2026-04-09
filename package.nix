{
  lib,
  rustPlatform,
  openblas,
  onnxruntime,
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
  buildInputs = [ openblas onnxruntime ];

  ORT_DYLIB_PATH = "${onnxruntime}/lib/libonnxruntime.dylib";

  # Copy the onnxruntime dylib into the cargo target dir before
  # cargoInstallHook runs — it will then install it to $out/lib
  postBuild = ''
    cp ${onnxruntime}/lib/libonnxruntime.dylib \
       target/aarch64-apple-darwin/release/
    cp ${onnxruntime}/lib/libonnxruntime.1.24.4.dylib \
       target/aarch64-apple-darwin/release/
  '';

  # Fix the binary's rpath to find the dylib next to it in $out/lib
  postInstall = ''
    install_name_tool \
      -add_rpath "@executable_path/../lib" \
      $out/bin/nix-app
  '';

  meta = {
    description = "My Rust CLI";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
})
