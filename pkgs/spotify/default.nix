{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  callPackage,
  spotify,
}: let
  inherit (stdenv.hostPlatform) system;

  pname = "spotify";
  version = "10.13-14";
  src = fetchurl {
    url = "https://download.scdn.co/Spotify-${version}.dmg";
    sha256 = "sha256-kf6puQORxdWWR8MWDN7+34aVKKX+1tZwHeWQlFQOULE=";
  };

  meta = with lib; {
    homepage = "https://www.spotify.com/";
    description = "Play music from the Spotify music service";
    sourceProvenance = with sourceTypes; [binaryNativeCode];
    license = licenses.unfree;
    platforms = ["x86_64-darwin" "aarch64-darwin"];
    mainProgram = "spotify";
  };

  linux = spotify;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
  if stdenv.isDarwin
  then darwin
  else linux
