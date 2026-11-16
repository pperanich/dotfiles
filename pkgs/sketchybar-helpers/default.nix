{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "sketchybar-helpers";
  version = "0.1.0";

  src = ./.;

  buildPhase = ''
    runHook preBuild

    $CC -std=c99 -O3 -Wall -Wextra cpu_load.c -o cpu_load
    $CC -std=c99 -O3 -Wall -Wextra network_load.c -lm -o network_load
    $CC -std=c99 -O3 -Wall -Wextra -Wno-deprecated-declarations \
      -framework Carbon -framework ApplicationServices -framework CoreGraphics -framework CoreFoundation \
      menus.c -o menus

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 cpu_load $out/bin/cpu_load
    install -Dm755 network_load $out/bin/network_load
    install -Dm755 menus $out/bin/menus

    runHook postInstall
  '';

  meta = {
    description = "Native macOS event providers and menu bar helpers for SketchyBar";
    platforms = lib.platforms.darwin;
  };
}
