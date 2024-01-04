{ lib
, stdenv
, fetchurl
, makeWrapper
, callPackage
, logseq
}:
let
  inherit (stdenv.hostPlatform) system;

  pname = "logseq-darwin";

  x86_64-darwin-version = "0.10.2";
  x86_64-darwin-sha256 = "sha256-yYkKVZ5DhbV4tfq/n5EfnkuGvcl9h8X+BuhPkjUGOzE=";

  aarch64-darwin-version = "0.10.2";
  aarch64-darwin-sha256 = "0yyqmyicf4rkpvp6al2kb7g188xhg3m8hyi24a23yhnil8hk2r3v";

  version = {
    x86_64-darwin = x86_64-darwin-version;
    aarch64-darwin = aarch64-darwin-version;
  }.${system} or "";


  src =
    let
      base = "https://github.com/logseq/logseq/releases/download/${version}";
    in
      {
        x86_64-darwin = fetchurl {
          url = "${base}/Logseq-darwin-x64-${version}.dmg";
          sha256 = x86_64-darwin-sha256;
        };
        aarch64-darwin = fetchurl {
          url = "${base}/Logseq-darwin-arm64-${version}.dmg";
          sha256 = aarch64-darwin-sha256;
        };
      }.${system} or "";

  meta = with lib; {
    description = "A local-first, non-linear, outliner notebook for organizing and sharing your personal knowledge base";
    homepage = "https://github.com/logseq/logseq";
    changelog = "https://github.com/logseq/logseq/releases/tag/${version}";
    license = licenses.agpl3Plus;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "logseq";
  };

  package = callPackage ../dmg-app.nix {
    inherit pname version src meta;
  };
in
package
