_: {
  flake.modules.nixos.terminalMultiplexers = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      tmux # Terminal multiplexer
      tmux-sessionizer # The fastest way to manage projects as tmux sessions
    ];
  };

  flake.modules.homeModules.terminalMultiplexers = {
    pkgs,
    lib,
    ...
  }: {
    home.packages = with pkgs;
      [
        tmux # Terminal multiplexer
        tmux-sessionizer # The fastest way to manage projects as tmux sessions
        zellij # A terminal workspace with batteries included
        update-display # Re-export DISPLAY in tmux shells
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        reattach-to-user-namespace # A wrapper that provides access to the Mac OS X pasteboard service
        pam-reattach # Reattach to the user's GUI session on macOS during authentication (for Touch ID support in tmux)
      ];
  };
}
