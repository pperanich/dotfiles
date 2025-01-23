{outputs, ...}: {
  imports = outputs.homeManagerModules;

  sops = {
    secrets = {
      "private_keys/pperanich" = {};
    };
  };

  home = {
    username = "pperanich";
  };
}
