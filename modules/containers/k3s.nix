_: {
  # NixOS system-level K3s configuration
  flake.modules.nixos.k3s =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.k3s;
    in
    {
      options.features.k3s = {
        role = lib.mkOption {
          type = lib.types.enum [
            "server"
            "agent"
          ];
          default = "server";
          description = "K3s role: server or agent";
        };
        tokenFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to file containing the K3s cluster token";
        };
        serverAddr = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://10.0.0.1:6443";
          description = "Server address for agent nodes";
        };
        clusterInit = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Initialize the cluster (first server only)";
        };
        disableComponents = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "traefik"
            "servicelb"
          ];
          description = "K3s components to disable";
        };
        extraFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional flags for K3s";
        };
      };

      config = {
        # K3s service
        services.k3s = {
          enable = true;
          inherit (cfg) role;
          inherit (cfg) clusterInit;
          inherit (cfg) serverAddr;
          inherit (cfg) tokenFile;
          extraFlags = (map (component: "--disable=${component}") cfg.disableComponents) ++ cfg.extraFlags;
        };

        # Firewall configuration
        networking.firewall = {
          allowedTCPPorts = [
            6443 # Kubernetes API server
            2379 # etcd client requests
            2380 # etcd peer communication
            10250 # Kubelet API
            10251 # kube-scheduler
            10252 # kube-controller-manager
          ];
          allowedUDPPorts = [
            8472 # Flannel VXLAN
          ];
        };

        # Required kernel modules
        boot.kernelModules = [
          "br_netfilter"
          "overlay"
        ];

        # Kernel parameters
        boot.kernel.sysctl = {
          "net.bridge.bridge-nf-call-iptables" = 1;
          "net.ipv4.ip_forward" = 1;
        };

        # Ensure cgroups v2
        systemd.enableUnifiedCgroupHierarchy = true;

        # Required packages
        environment.systemPackages = with pkgs; [
          k3s
          kubectl
          kubernetes-helm
        ];
      };
    };

  # Home Manager K3s tools
  flake.modules.homeManager.k3s =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubectl
        kubernetes-helm
        k9s # Terminal UI for Kubernetes
        kubectx # Switch between clusters/namespaces
        kustomize # Kubernetes configuration management
      ];
    };
}
