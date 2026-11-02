# Install Rex support without taking ownership of the Stow-managed config files.
{ inputs, ... }:
{
  flake.modules.homeManager.rex =
    { pkgs, ... }:
    {
      imports = [ inputs.rex.homeManagerModules.default ];

      programs.rex = {
        enable = true;
        config = null; # home/.config/rex/init.lua
        sshGuard = false; # home/.ssh/config includes home/.config/rex/ssh_config
      };

      # No services.rex: the macOS app owns its server. Linux service enablement
      # is a separate host decision, not a side effect of installing the CLI.
      home.packages = [ pkgs.rexpick ];
    };
}
