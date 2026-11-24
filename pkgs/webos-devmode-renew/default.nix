# Renew and verify an LG webOS Developer Mode session via LG's developer API.
{
  lib,
  writeShellApplication,
  coreutils,
  curl,
  jq,
}:
(writeShellApplication {
  name = "webos-devmode-renew";
  runtimeInputs = [
    coreutils
    curl
    jq
  ];
  text = builtins.readFile ./webos-devmode-renew.sh;
})
// {
  meta = with lib; {
    description = "Renew and verify an LG webOS Developer Mode session";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "webos-devmode-renew";
  };
}
