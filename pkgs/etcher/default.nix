{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  callPackage,
  etcher,
}: let
  inherit (stdenv.hostPlatform) system;

  pname = "etcher";
  version = "1.18.11";
  src = fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${version}/balenaEtcher-1.18.11.dmg";
    sha256 = "sha256-dcw7P7WmCYWDro9IErnZtnoeMNV01KyTnL/zqGZRhG8=";
  };

  meta = with lib; {
    description = "Flash OS images to SD cards and USB drives, safely and easily";
    homepage = "https://etcher.io/";
    license = licenses.asl20;
    mainProgram = pname;
    maintainers = with maintainers; [wegank];
    platforms = ["x86_64-darwin" "aarch64-darwin"];
    sourceProvenance = with sourceTypes; [binaryNativeCode];
  };

  linux = etcher;
  darwin = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
  if stdenv.isDarwin
  then darwin
  else linux
