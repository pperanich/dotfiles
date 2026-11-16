# Host discovery and system builder (`machines/<host>/configuration.nix`).
# Modeled directly on `templates/private/modules/flake-parts/hosts.nix`.
{
  inputs,
  config,
  ...
}:
let
  # Use inputs.nixpkgs's extended lib (config.flake.lib), NOT flake-parts'
  # bundled nixpkgs-lib, in machine specialArgs so NixOS modules match nixpkgs.
  inherit (config.flake) lib modules;
  dir = ../../machines;

  specialArgs = {
    inherit inputs lib modules;
    outputs = config.flake;
  };

  # Choose the builder before evaluating the module system. Only force the
  # platform, leaving imports alone. It must be declared in configuration.nix
  # itself and cannot depend on config, pkgs, or other module-system arguments.
  platformOf =
    host:
    let
      f = import (dir + "/${host}/configuration.nix");
      args = lib.mapAttrs (
        name: _:
        specialArgs.${name}
          or (throw "hosts.nix: ${host}'s nixpkgs.hostPlatform must not depend on `${name}`, which only exists once the module system is running")
      ) (builtins.functionArgs f);
      attrs = if builtins.isFunction f then f args else f;
      raw =
        attrs.nixpkgs.hostPlatform
          or (throw "hosts.nix: machines/${host}/configuration.nix must set nixpkgs.hostPlatform directly, even if hardware-configuration.nix also sets it");
      unwrap = v: if v ? _type && v._type == "override" then unwrap v.content else v;
      platform = unwrap raw;
    in
    if lib.isString platform then
      platform
    else
      platform.system
        or (throw "hosts.nix: ${host}'s nixpkgs.hostPlatform must be a system string or a platform attrset");

  classOf =
    host:
    let
      platform = lib.systems.elaborate (platformOf host);
    in
    if platform.isDarwin then
      "darwin"
    else if platform.isLinux then
      "nixos"
    else
      throw "hosts.nix: ${host}'s platform ${platform.system} is neither Linux nor Darwin";

  hosts = lib.filterAttrs (
    host: type: type == "directory" && builtins.pathExists (dir + "/${host}/configuration.nix")
  ) (if builtins.pathExists dir then builtins.readDir dir else { });

  nixosBaseline =
    host:
    let
      facterJson = dir + "/${host}/facter.json";
      hasDisko = builtins.pathExists (dir + "/${host}/disko.nix");
      hasFacter = builtins.pathExists facterJson;
    in
    lib.optional hasDisko inputs.disko.nixosModules.disko
    ++ lib.optional hasFacter {
      hardware.facter.reportPath = lib.mkDefault facterJson;
    }
    ++ [
      (
        { config, ... }:
        {
          # Preserve NixOS/nixos-anywhere default hostId used by ZFS rpool on pp-nas1
          networking.hostId = lib.mkDefault "8425e349";
          boot.zfs.forceImportRoot = lib.mkDefault false;
          services.zfs = lib.mkIf config.boot.zfs.enabled {
            autoSnapshot.enable = lib.mkDefault (!config.services.sanoid.enable);
            autoSnapshot.monthly = lib.mkDefault 1;
            autoScrub.enable = lib.mkDefault true;
          };

          # Keep sshd enabled with hardened key-only defaults
          services.openssh = {
            enable = lib.mkDefault true;
            settings = {
              PasswordAuthentication = lib.mkDefault false;
              KbdInteractiveAuthentication = lib.mkDefault false;
              PermitRootLogin = lib.mkDefault "no";
            };
          };

          # Networking defaults. Keep the block whole: networkd
          # with wait-online on can fail a switch on a host with an unplugged interface.
          networking.useHostResolvConf = lib.mkDefault false;
          networking.firewall.allowPing = lib.mkDefault true;
          systemd.services.NetworkManager-wait-online.enable = lib.mkDefault false;
          systemd.network.wait-online.enable = lib.mkDefault false;
          systemd.network.networks."99-ethernet-default-dhcp".networkConfig.MulticastDNS = lib.mkDefault true;
          systemd.network.networks."99-wireless-client-dhcp".networkConfig.MulticastDNS = lib.mkDefault true;
          networking.firewall.allowedUDPPorts = lib.mkIf config.networking.useNetworkd [ 5353 ];
          networking.useNetworkd = lib.mkDefault true;

          # Root has no password under this builder, and the physical console is the recovery
          # path, so let it reach a root shell in initrd and in stage-2 emergency and rescue mode.
          boot.initrd.systemd.emergencyAccess = lib.mkDefault true;
          systemd.services.emergency.environment.SYSTEMD_SULOGIN_FORCE = lib.mkDefault "1";
          systemd.services.rescue.environment.SYSTEMD_SULOGIN_FORCE = lib.mkDefault "1";
        }
      )
    ];

  buildHost =
    host:
    let
      class = classOf host;
      builder =
        if class == "darwin" then inputs.darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
      nhVar = if class == "darwin" then "NH_DARWIN_FLAKE" else "NH_OS_FLAKE";
    in
    builder {
      inherit specialArgs;
      modules = [
        # $HOME expands when the shell sources this; matches ~/dotfiles checkout.
        { environment.variables.${nhVar} = "$HOME/dotfiles#${host}"; }
        (dir + "/${host}/configuration.nix")
      ]
      ++ lib.optionals (class == "nixos") (nixosBaseline host);
    };

  hostsOfClass =
    class:
    lib.mapAttrs (host: _: buildHost host) (lib.filterAttrs (host: _: classOf host == class) hosts);

  expectedHosts = [
    "pp-ld1"
    "pp-ml1"
    "pp-nas1"
    "pp-router1"
    "pp-rpi1"
    "pp-wsl1"
  ];
  actualHosts = builtins.attrNames hosts;

  evaluatedHosts = config.flake.nixosConfigurations // config.flake.darwinConfigurations;

  hostDrvs = lib.mapAttrs (
    host: cfg:
    let
      rawDrv =
        if classOf host == "darwin" then cfg.system.drvPath else cfg.config.system.build.toplevel.drvPath;
    in
    builtins.unsafeDiscardStringContext rawDrv
  ) evaluatedHosts;
  lines = lib.mapAttrsToList (host: drv: "${host}=${drv}") hostDrvs;
in
{
  flake = {
    nixosConfigurations = hostsOfClass "nixos";
    darwinConfigurations = hostsOfClass "darwin";
  };

  perSystem =
    { pkgs, ... }:
    {
      checks.hosts-eval =
        assert actualHosts == expectedHosts;
        assert lib.all (drv: lib.hasPrefix "/nix/store/" drv) (builtins.attrValues hostDrvs);
        pkgs.runCommand "hosts-eval" { } ''
          cat <<'EOF' > "$out"
          ${lib.concatStringsSep "\n" lines}
          EOF
        '';
    };
}
