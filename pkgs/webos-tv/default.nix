# CLI wrapper around ares-cli for pairing an LG webOS TV and managing Moonlight.
{
  lib,
  writeShellApplication,
  ares-cli,
  coreutils,
  curl,
  jq,
  webos-devmode-renew,
}:
(writeShellApplication {
  name = "webos-tv";
  runtimeInputs = [
    ares-cli
    coreutils
    curl
    jq
    webos-devmode-renew
  ];
  text = builtins.readFile ./webos-tv.sh;
})
// {
  meta = with lib; {
    description = "Pair an LG webOS TV and manage Moonlight via ares-cli";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "webos-tv";
  };
}
