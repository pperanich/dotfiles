{
  # Override these
  pname,
  version,
  src,
  meta,
  expectedTeamId ? null,
  # Deps
  lib,
  stdenv,
  makeWrapper,
  nix-update-script,
}:
stdenv.mkDerivation {
  inherit
    pname
    version
    src
    meta
    ;
  phases = [
    "unpackPhase"
    "installPhase"
  ];

  nativeBuildInputs = [ makeWrapper ];

  passthru.updateScript = nix-update-script { };

  unpackCmd = ''
    hdiutil="/usr/bin/hdiutil"
    echo "File to unpack: $curSrc"
    if ! [[ "$curSrc" =~ \.dmg$ ]]; then return 1; fi
    mnt=$(mktemp -d "''${TMPDIR:-/tmp}/dmg-XXXXXXXXXX")

    finish() {
      if [[ -d "$mnt" ]]; then
        echo "Detaching $mnt"
        "$hdiutil" detach "$mnt" -force || true
        rm -rf "$mnt"
      fi
    }
    trap finish EXIT

    echo "Attaching $mnt"
    "$hdiutil" attach -nobrowse -readonly "$curSrc" -mountpoint "$mnt"

    echo "What's in the mount dir?"
    ls -la "$mnt/"

    echo "Copying contents"
    shopt -s extglob nullglob
    DEST="$PWD"
    (
      cd "$mnt"
      for entry in !(Applications); do
        cp -a "$entry" "$DEST/"
      done
    )
    sourceRootPath=$(find "$DEST" -maxdepth 1 -name "*.app" -print -quit)
    if [[ -z "$sourceRootPath" ]]; then
      echo "ERROR: No .app bundle found in DMG $curSrc" >&2
      return 1
    fi
    sourceRoot=$(basename "$sourceRootPath")
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/$sourceRoot/"
    cp -R . "$out/Applications/$sourceRoot/"

    ${lib.optionalString (expectedTeamId != null && stdenv.hostPlatform.isDarwin) ''
      codesign_bin="/usr/bin/codesign"
      app_path="$out/Applications/$sourceRoot"
      echo "Verifying code signature and TeamIdentifier (${lib.escapeShellArg expectedTeamId}) for $app_path"
      "$codesign_bin" --verify --deep --strict "$app_path"
      actual_team_id=$("$codesign_bin" -dv "$app_path" 2>&1 | sed -n 's/^TeamIdentifier=//p')
      if [[ "$actual_team_id" != ${lib.escapeShellArg expectedTeamId} ]]; then
        echo "ERROR: TeamIdentifier mismatch for $app_path: expected ${lib.escapeShellArg expectedTeamId}, got '$actual_team_id'" >&2
        exit 1
      fi
    ''}

    mkdir -p "$out/bin"
    for bin in "$out/Applications/$sourceRoot/Contents/MacOS/"*; do
      if [[ "$(basename "$bin")" == "$pname" && "$bin" != *.dylib && -f "$bin" && -x "$bin" ]]; then
        makeWrapper "$bin" "$out/bin/$(basename "$bin")"
      fi
    done
    runHook postInstall
  '';
}
