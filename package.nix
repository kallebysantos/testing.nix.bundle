{
  lib,
  stdenv,
  rustPlatform,
  openblas,
  onnxruntime,
  pkg-config,
  patchelf,
}:
let
  nix-app-unwrapped = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "nix-app-unwrapped";
    version = "0.1.0";
    src = ./.;
    cargoLock = {
      lockFile = ./Cargo.lock;
    };
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openblas onnxruntime ];
    ORT_DYLIB_PATH = "${onnxruntime}/lib/libonnxruntime.dylib";
    doCheck = false;
  });
in
stdenv.mkDerivation {
  name = "nix-app";
  version = "0.1.0";
  dontUnpack = true;
  dontPatchShebangs = true;
  nativeBuildInputs = lib.optionals stdenv.isLinux [ patchelf ];

buildPhase = ''
  mkdir -p $out/bin $out/lib

  cp ${nix-app-unwrapped}/bin/nix-app $out/bin/.nix-app-wrapped

  get_deps() {
    if [ "$(uname)" = "Darwin" ]; then
      otool -L "$1" 2>/dev/null | grep /nix/store | awk '{print $1}'
    else
      ldd "$1" 2>/dev/null | grep /nix/store | awk '{print $3}'
    fi
  }

  should_exclude() {
    case "$1" in
      libc.so*|libc-*.so*|ld-linux*.so*|libdl.so*|libpthread.so*|libm.so*|libresolv.so*|librt.so*)
        return 0 ;;
      *) return 1 ;;
    esac
  }

  copy_dep() {
    local dep="$1"
    local libname=$(basename "$dep")
    [ -f "$out/lib/$libname" ] && return  # already copied
    should_exclude "$libname" && return
    [ -f "$dep" ] && cp "$dep" $out/lib/ 2>/dev/null || true
  }

  # Seed: direct deps of binary + onnxruntime and all its siblings
  for dep in $(get_deps $out/bin/.nix-app-wrapped); do
    copy_dep "$dep"
  done
  cp ${onnxruntime}/lib/libonnxruntime*.dylib $out/lib/ 2>/dev/null || \
  cp ${onnxruntime}/lib/libonnxruntime*.so*   $out/lib/ 2>/dev/null || true

  # Iterative crawl until no new deps appear
  for iteration in 1 2 3 4 5; do
    before=$(ls $out/lib/ | wc -l)

    for lib in $out/lib/*; do
      [ -f "$lib" ] || continue
      for dep in $(get_deps "$lib"); do
        copy_dep "$dep"
      done
    done

    after=$(ls $out/lib/ | wc -l)
    echo "Iteration $iteration: $before -> $after libs"
    [ "$before" -eq "$after" ] && break
  done
'';

installPhase = ''
  cat > $out/bin/nix-app << 'EOF'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

if [ "$(uname)" = "Darwin" ]; then
  export DYLD_LIBRARY_PATH="$LIB_DIR''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
  export ORT_DYLIB_PATH="$LIB_DIR/libonnxruntime.dylib"
else
  export LD_LIBRARY_PATH="$LIB_DIR''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export ORT_DYLIB_PATH="$LIB_DIR/libonnxruntime.so"
fi

exec "$SCRIPT_DIR/.nix-app-wrapped" "$@"
EOF
  chmod +x $out/bin/nix-app
'';

  postFixup =
    lib.optionalString stdenv.isLinux ''
      INTERP=$(
        if [ "$(uname -m)" = "x86_64" ]; then echo "/lib64/ld-linux-x86-64.so.2";
        else echo "/lib/ld-linux-aarch64.so.1"; fi
      )
      patchelf --set-interpreter "$INTERP" \
               --set-rpath '$ORIGIN/../lib' \
               $out/bin/.nix-app-wrapped 2>/dev/null || true

      for lib in $out/lib/*.so*; do
        [ -f "$lib" ] && file "$lib" | grep -q ELF || continue
        patchelf --set-rpath '$ORIGIN' "$lib" 2>/dev/null || true
      done
    ''
    + lib.optionalString stdenv.isDarwin ''
      for dep in $(otool -L $out/bin/.nix-app-wrapped | grep /nix/store | awk '{print $1}'); do
        libname=$(basename "$dep")
        [ -f "$out/lib/$libname" ] || continue
        install_name_tool -change "$dep" "@rpath/$libname" \
          $out/bin/.nix-app-wrapped 2>/dev/null || true
      done
      install_name_tool -add_rpath "@executable_path/../lib" \
        $out/bin/.nix-app-wrapped 2>/dev/null || true

      for lib in $out/lib/*.dylib; do
        [ -f "$lib" ] || continue
        libname=$(basename "$lib")
        install_name_tool -id "@rpath/$libname" "$lib" 2>/dev/null || true
        install_name_tool -add_rpath "@loader_path" "$lib" 2>/dev/null || true
        for dep in $(otool -L "$lib" | grep /nix/store | awk '{print $1}'); do
          deplibname=$(basename "$dep")
          [ -f "$out/lib/$deplibname" ] || continue
          install_name_tool -change "$dep" "@rpath/$deplibname" \
            "$lib" 2>/dev/null || true
        done
      done
    '';

  meta = {
    description = "My Rust CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = [ ];
  };
}
