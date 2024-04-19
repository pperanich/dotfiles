{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, glibc
, gcc-unwrapped
, zeroc-ice
, libz
, freetype
, fontconfig
, libX11
, libxcb
, libXScrnSaver
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXtst
, libdrm
, libnotify
, libpulseaudio
, libuuid
, libICE
, libSM
}:
let
  pname = "fortinac-persistent-agent";
  version = "9.4.0.93";
in
stdenv.mkDerivation {
  name = pname;
  src = fetchurl {
    url = "https://apllinuxdepot.jhuapl.edu/linux/apl-software/deb/${pname}_${version}-1.amd64.deb";
    hash = "sha256-gS8sT+AJANYXN6jsNBzzvMxrcMP8ycdMTvxD9ZiHqeE=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    gcc-unwrapped
    libz
    freetype
    fontconfig.lib
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libdrm
    libnotify
    libuuid
    libxcb
    libICE
    libSM
  ];

  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
    mv $out/opt/com.bradfordnetworks/PersistentAgent/ $out/bin/
    rm -rf $out/opt
    rm -rf $out/lib
    rm -rf $out/etc

    chmod 755 $out
    ls -lahR $out
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
