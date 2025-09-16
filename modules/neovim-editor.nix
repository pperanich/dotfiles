_: {
  flake.modules.nixos.neovimEditor = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      pkg-config # C library configuration tool
    ];
  };

  flake.modules.homeModules.neovimEditor = {pkgs, ...}: {
    home.sessionVariables = {
      EDITOR = "nvim";
    };

    home.packages = with pkgs; [
      fzf # Command-line fuzzy finder
    ];

    programs.neovim = {
      enable = true;
      package = pkgs.neovim;
    };
  };
}
