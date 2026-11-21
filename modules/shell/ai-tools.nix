# CLI coding agents from numtide's llm-agents.nix.
# Their binary cache is configured for every host in modules/system/base.nix.
{ inputs, ... }:
{
  flake.modules = {
    homeManager.aiTools =
      { pkgs, lib, ... }:
      let
        agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        home.sessionVariables.PI_PROGRAM_STATUS = "1";

        home.packages = [
          agents.claude-code
          agents.claude-desktop
          agents.opencode2
          agents.codex
          agents.herdr
          agents.pi
          agents.antigravity-cli
          agents.antigravity-hub
          agents.qmd
        ]
        ++ lib.optional (agents ? handy) agents.handy;
      };
  };
}
