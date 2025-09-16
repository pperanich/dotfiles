_: {
  # NixOS audio system configuration for multimedia workflows
  flake.modules.nixos.multimediaTools = {pkgs, ...}: {
    # Audio system configuration
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
