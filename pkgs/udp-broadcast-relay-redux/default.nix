{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "udp-broadcast-relay-redux";
  version = "0-unstable-2024-07-28";

  src = fetchFromGitHub {
    owner = "udp-redux";
    repo = "udp-broadcast-relay-redux";
    rev = "5a5cd384bc944f40ebda3658b08ce0c1c9f00182";
    hash = "sha256-1T3zBqfseECr+jRD5BHWgcDOfSohDVaTNfAmfUvk+hY=";
  };

  # Single-file C project with simple Makefile
  makeFlags = [ "CC=${stdenv.cc.targetPrefix}cc" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 udp-broadcast-relay-redux $out/bin/udp-broadcast-relay-redux
    runHook postInstall
  '';

  meta = with lib; {
    description = "UDP broadcast/multicast relay for separated networks (SSDP, broadcast)";
    homepage = "https://github.com/udp-redux/udp-broadcast-relay-redux";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    mainProgram = "udp-broadcast-relay-redux";
  };
}
