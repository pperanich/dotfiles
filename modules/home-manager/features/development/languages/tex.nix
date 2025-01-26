# TeX/LaTeX development environment
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.development.languages;
in {
  config = lib.mkIf (cfg.enable && cfg.tex.enable) {
    programs.texlive = {
      enable = true;
    };
  };
}
