{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  callPackage,
  vlc,
}: let
  inherit (stdenv.hostPlatform) system;

  pname = "vlc";
  version = "3.0.20";
  src = fetchurl {
    url = "https://get.videolan.org/vlc/${version}/macosx/vlc-${version}-universal.dmg";
    sha256 = "sha256-IqGPOWzMmHbGDV+0QxFslv19BC2J1Z5Qzcuja/Od1Us=";
  };

  meta = with lib; {
    description = "Cross-platform media player and streaming server";
    homepage = "http://www.videolan.org/vlc/";
    license = lib.licenses.lgpl21Plus;
    platforms = ["x86_64-darwin" "aarch64-darwin"];
  };

  linux = vlc;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
  if stdenv.isDarwin
  then darwin
  else linux
