{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  programs.vscode = {
    enable = true;
    # package = pkgs.vscode.fhsWithPackages (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
    # extensions = with pkgs.vscode-extensions; [
    #   # vscodevim.vim
    #   # vspacecode.whichkey
    #   vspacecode.vspacecode
    #   yzhang.markdown-all-in-one
    # ];
  };
}
