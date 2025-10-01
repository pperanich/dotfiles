# Network utilities module - HTTP clients, network monitoring, and connectivity tools
{...}: {
  flake.modules.homeManager.networkUtilities = {pkgs, ...}: {
    home.packages = with pkgs; [
      # HTTP clients - traditional
      curl # Command line tool for transferring data with URL syntax
      wget # Tool for retrieving files using HTTP, HTTPS, and FTP

      # HTTP clients - modern alternatives
      httpie # Command line HTTP client whose goal is to make CLI human-friendly
      xh # Friendly and fast tool for sending HTTP requests
      curlie # Frontend to curl that adds the ease of use of httpie, without compromising on features and performance

      # Network monitoring and utilities
      bandwhich # A CLI utility for displaying current network utilization
    ];
  };

  # System-level network utilities (if needed for system administration)
  flake.modules.nixos.networkUtilities = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      curl # Essential for system operations and package management
      wget # Often required by system scripts and services
      bandwhich # Useful for system network monitoring
    ];
  };
}
