_: {
  # NixOS hardware acceleration support for multimedia processing
  flake.modules.nixos.multimediaTools = {pkgs, ...}: {
    # Hardware acceleration support for video processing
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
    };

    # System-wide multimedia environment for hardware acceleration
    environment.variables = {
      # Enable hardware acceleration for multimedia applications
      LIBVA_DRIVER_NAME = "iHD"; # Intel graphics
      VDPAU_DRIVER = "va_gl"; # VDPAU over VA-API
    };
  };
}
