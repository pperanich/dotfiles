# CLI coding agents from numtide's llm-agents.nix.
{ inputs, ... }:
let
  substituters = [ "https://cache.numtide.com" ];
  trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
in
{
  flake.modules = {
    # extra-* so this appends to Determinate's managed nix.conf rather than
    # replacing cache.nixos.org.
    darwin.aiTools.determinateNix.customSettings = {
      extra-substituters = substituters;
      extra-trusted-public-keys = trusted-public-keys;
    };
    nixos.aiTools.nix.settings = {
      extra-substituters = substituters;
      extra-trusted-public-keys = trusted-public-keys;
    };

    homeManager.aiTools =
      { pkgs, ... }:
      let
        agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        home.packages = [
          agents.claude-code
          agents.opencode
          agents.codex
          agents.herdr
          agents.pi
          agents.handy
        ];
      };
  };
}
