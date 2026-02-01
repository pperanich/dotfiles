_:
{
  flake.modules.homeManager.opencode =
    {
      pkgs,
      ...
    }:
    {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode;

        web = {
          enable = true;
          extraArgs = [
            "--port"
            "4096"
            "--hostname"
            "127.0.0.1"
            "--cors"
            "https://app.opencode.ai"
          ];
        };
      };
    };
}
