{
  # Override these
  pname,
  version,
  src,
  meta,
  # Deps
  stdenv,
  makeWrapper,
  nix-update-script,
}:
stdenv.mkDerivation {
  inherit pname version src meta;
  phases = ["unpackPhase" "installPhase"];

  nativeBuildInputs = [makeWrapper];

  passthru.updateScript = nix-update-script {};

  unpackCmd = ''
    hdiutil="/usr/bin/hdiutil"
    echo "File to unpack: $curSrc"
    if ! [[ "$curSrc" =~ \.dmg$ ]]; then return 1; fi
    mnt=$(mktemp -d -t ci-XXXXXXXXXX)

    function finish {
      if [ -d $mnt ]; then
        echo "Detaching $mnt"
        $hdiutil detach $mnt -force || true
        rm -rf $mnt
      fi
    }
    trap finish EXIT

    echo "Attaching $mnt"
    $hdiutil attach -nobrowse -readonly $src -mountpoint $mnt

    echo "What's in the mount dir"?
    ls -la $mnt/

    echo "Copying contents"
    shopt -s extglob
    DEST="$PWD"
    (cd "$mnt"; cp -a !(Applications) "$DEST/")
    sourceRootPath=$(find "$DEST" -maxdepth 1 -name "*.app")
    sourceRoot=$(basename "$sourceRootPath")
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/$sourceRoot/"
    cp -R . "$out/Applications/$sourceRoot/"

    mkdir -p $out/bin
    for bin in "$out/Applications/$sourceRoot/Contents/MacOS/*"; do
      [[ "$(basename "$bin")" =~ $pname && ! "$bin" =~ \.dylib && -f "$bin" && -x "$bin" ]] &&  makeWrapper "$bin" "$out/bin/$(basename "$bin")"
    done
    runHook postInstall
  '';
}
