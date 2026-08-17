{ writeShellApplication }:
writeShellApplication {
  name = "hello-dendritic";
  text = ''
    echo "dendritic flake is wired up"
  '';
}
