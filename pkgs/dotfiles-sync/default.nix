# Fast-forward a host's dotfiles checkout to the commit its generation was built from.
{
  lib,
  writeShellApplication,
  coreutils,
  git,
  openssh,
}:
(writeShellApplication {
  name = "dotfiles-sync";
  runtimeInputs = [
    coreutils
    git
    openssh
  ];
  text = builtins.readFile ./dotfiles-sync.sh;
})
// {
  meta = with lib; {
    description = "Fast-forward the dotfiles checkout to the deployed flake revision";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "dotfiles-sync";
  };
}
