{ lib
, fetchurl
, callPackage
}:
let
  pname = "shottr";
  version = "1.7.2";

  src = fetchurl {
    url = "https://shottr.cc/dl/Shottr-${version}.dmg";
    sha256 = "sha256-8KPYzIZ1jiL5Z5DFnMRJ0a/W6C554GhNllYY5xz5Lkw=";
  };

  meta = with lib; {
    description = "Shottr is a tiny and fast mac screenshot tool";
    homepage = "https://shottr.cc";
    changelog = "https://shottr.cc/#section-releasenotes";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "shottr";
  };
in
callPackage ../dmg-app.nix {
  inherit pname version src meta;
}
