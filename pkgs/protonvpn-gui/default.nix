{ lib
, stdenv
, fetchurl
, makeWrapper
, callPackage
, protonvpn-gui
}:
let
  inherit (stdenv.hostPlatform) system;

  pname = "protonvpn-gui";
  version = "4.1.1";
  src = fetchurl {
    url = "https://protonvpn.com/download/ProtonVPN_mac_v${version}.dmg";
    sha256 = "sha256-AL359+HGd5vrBZv5gOW6IOlK45c3DEV7Xl9SBI8LW20=";
  };

  meta = with lib; {
    description = "Official ProtonVPN Linux app";
    homepage = "https://github.com/ProtonVPN/linux-app";
    maintainers = with maintainers; [ wolfangaukang ];
    license = licenses.gpl3Plus;
    mainProgram = "protonvpn";
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
  };

  linux = protonvpn-gui;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
if stdenv.isDarwin
then darwin
else
  linux
