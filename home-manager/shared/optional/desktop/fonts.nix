{pkgs, ...}: {
  home.packages = with pkgs; [
    nerd-fonts.sauce-code-pro
    nerd-fonts.iosevka
    nerd-fonts.im-writing
    nerd-fonts.overpass
    nerd-fonts.fira-mono
    nerd-fonts.fira-code
    # Add below once the following is closed: https://github.com/NixOS/nixpkgs/issues/270222
    twitter-color-emoji
    sketchybar-app-font
    apple-fonts
  ];

  # required to autoload fonts from packages installed via Home Manager
  fonts.fontconfig.enable = true;
}
