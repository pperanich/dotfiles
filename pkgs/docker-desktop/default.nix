{ lib
, stdenv
, fetchurl
, callPackage
}:
let
  inherit (stdenv.hostPlatform) system;

  pname = "docker-desktop";

  x86_64-darwin-version = "4.26.1";
  x86_64-darwin-sha256 = "sha256-YX4H8EzYozfBie/PwFEJ/J74PDE+oQHFIFk8ecNml88=";

  aarch64-darwin-version = "4.26.1";
  aarch64-darwin-sha256 = "0yyqmyicf4rkpvp6al2kb7g188xhg3m8hyi24a23yhnil8hk2r3v";

  version = {
    x86_64-darwin = x86_64-darwin-version;
    aarch64-darwin = aarch64-darwin-version;
  }.${system} or "";
  # Can find this by inspected url of download in release notes for version.
  tag = "131620";

  src =
    let
      base = "https://desktop.docker.com/mac/main";
      app_name = "Docker.dmg";
    in
      {
        x86_64-darwin = fetchurl {
          url = "${base}/amd64/${tag}/${app_name}";
          sha256 = x86_64-darwin-sha256;
        };
        aarch64-darwin = fetchurl {
          url = "${base}/arm64/${tag}/${app_name}";
          sha256 = aarch64-darwin-sha256;
        };
      }.${system} or "";

  meta = with lib; {
    description = "The #1 containerization software for developers and teams";
    homepage = "https://www.docker.com/";
    changelog = "https://docs.docker.com/release-notes/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "docker";
  };
in
callPackage ../dmg-app.nix {
  inherit pname version src meta;
}
