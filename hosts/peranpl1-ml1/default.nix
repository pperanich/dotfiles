# Host configuration for peranpl1-ml1
{outputs, ...}: {
  imports = builtins.attrValues outputs.darwinModules;

  # Enable the modules
  my = {
    core.enable = true;
    users.peranpl1.enable = true;
    features = {
      sketchybar.enable = true;
      yabai.enable = true;
      skhd.enable = true;
    };
  };

  # Host-specific configuration goes here
  networking.hostName = "peranpl1-ml1";
  nixpkgs.hostPlatform = "x86_64-darwin";
}
