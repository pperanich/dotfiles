{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
}:
stdenv.mkDerivation {
  pname = "fortinac-persistent-agent";
  version = "9.4.0.93";

  src = fetchurl {
    url = "https://apllinuxdepot.jhuapl.edu/linux/apl-software/deb/${pname}_${version}-1.amd64.deb";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r usr $out
    cp -r usr/share $out/share
  '';

  meta = with lib; {
    homepage = "https://docs.fortinet.com/document/fortinac/9.4.0/administration-guide/143138/persistent-agent";
    description = "Identify and scan hosts for compliance with an endpoint compliance policy";
    platforms = [ "x86_64-linux" ];
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
  };
}
