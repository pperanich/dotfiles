{ lib
, stdenv
, fetchurl
, makeWrapper
, callPackage
, zotero
}:
let
  inherit (stdenv.hostPlatform) system;

  pname = "zotero";
  version = "6.0.30";

  src = fetchurl {
    url = "https://download.zotero.org/client/release/${version}/Zotero-${version}.dmg";
    sha256 = "sha256-J3Ex4Xg+4TmhBouheggybzsS0RVuWUxXN6+A5qTgXP4=";
  };

  meta = with lib; {
    homepage = "https://www.zotero.org";
    description = "Collect, organize, cite, and share your research sources";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.agpl3Only;
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
  };

  linux = zotero;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
if stdenv.isDarwin
then darwin
else
  linux
