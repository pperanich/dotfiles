{ config, pkgs, lib, inputs, ... }:
let
    emacsSrc = pkgs.fetchFromGitHub {
      owner="emacs-mirror";
      repo = "emacs";
      rev = "835d2b6acbe42b0bdef8f6e5f00fb0adbd1e3bcb";
      hash = "sha256-QZ1ike7Q46DeG6zuGVSej4a8VMvBMqE9zo6IzXwnTKI=";
    }; 
in
{
  nixpkgs = {
    config = {
      packageOverrides = pkgs: {
        emacsGit = pkgs.emacsGit.overrideAttrs (attrs: { src = emacsSrc; });
      };
    };
  };
}
