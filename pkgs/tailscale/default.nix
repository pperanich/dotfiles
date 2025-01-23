{
  lib,
  fetchurl,
  stdenv,
  callPackage,
  nix-update-script,
  makeWrapper,
}: let
  pname = "tailscale";
  version = "1.7.2";

  src = fetchurl {
    url = "https://pkgs.tailscale.com/stable/Tailscale-1.56.1-macos.zip";
    sha256 = "sha256-Zd73UoCoOiCzYBs/g+fZt0t8T7Oek7hYiQWPSAO8Qx8=";
  };

  meta = with lib; {
    description = "Secure, remote access to servers";
    homepage = "https://tailscale.com/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [binaryNativeCode];
    maintainers = with maintainers; [];
    platforms = ["x86_64-darwin" "aarch64-darwin"];
    mainProgram = "tailscale";
  };
in
  stdenv.mkDerivation {
    inherit pname version src meta;
    phases = ["unpackPhase" "installPhase"];

    nativeBuildInputs = [makeWrapper];

    passthru.updateScript = nix-update-script {};

    unpackCmd = ''
      echo "File to unpack: $curSrc"
      mnt=$(mktemp -d -t ci-XXXXXXXXXX)

      function finish {
        echo "Destroying $mnt"
        rm -rf $mnt
      }
      trap finish EXIT

      echo "Unzipping to $mnt"
      $hdiutil attach -nobrowse -readonly $src -mountpoint $mnt
      unzip $curSrc -d $mnt

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
