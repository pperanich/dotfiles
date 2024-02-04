{ lib
, stdenv
, fetchurl
, makeWrapper
, callPackage
, brave
}:
let
  inherit (stdenv.hostPlatform) system;

  pname = "brave";
  version = "1.62.156";
  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/Brave-Browser-universal.dmg";
    sha256 = "sha256-53khZAzAptV26RCweW/Y5KH8pUGeLPBmc+4E2EVnC2I=";
  };

  meta = with lib; {
    homepage = "https://brave.com/";
    description = "Privacy-oriented browser for Desktop and Laptop computers";
    changelog = "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP.md#" + replaceStrings [ "." ] [ "" ] version;
    longDescription = ''
      Brave browser blocks the ads and trackers that slow you down,
      chew up your bandwidth, and invade your privacy. Brave lets you
      contribute to your favorite creators automatically.
    '';
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.mpl20;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
  };

  linux = brave;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
if stdenv.isDarwin
then darwin
else
  linux
