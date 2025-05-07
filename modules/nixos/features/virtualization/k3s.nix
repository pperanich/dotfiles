# k3s Kubernetes module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.virtualization.k3s;
in {
  options.my.features.virtualization.k3s = {
    enable = lib.mkEnableOption "k3s lightweight Kubernetes";
    role = lib.mkOption {
      type = lib.types.enum ["server" "agent"];
      default = "server";
      description = "Role of this node in the k3s cluster";
    };
    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Address of the server node when running as agent";
      example = "https://server-node:6443";
    };
    token = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Token for joining the cluster";
    };
    extraServerArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments to pass to the server";
      example = ["--disable=traefik" "--disable=servicelb"];
    };
    extraAgentArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments to pass to the agent";
      example = ["--node-label=region=us-east"];
    };
    enableLocalStorage = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable local path provisioner for storage";
    };
  };

  config = lib.mkIf cfg.enable {
    # Basic k3s setup
    services.k3s = {
      enable = true;
      role = cfg.role;
      serverAddr = lib.mkIf (cfg.role == "agent") cfg.serverAddr;
      token = cfg.token;

      # Set extra arguments based on role
      extraFlags =
        if cfg.role == "server"
        then (lib.optional cfg.enableLocalStorage "--disable=local-storage=false") ++ cfg.extraServerArgs
        else cfg.extraAgentArgs;
    };

    # Add CLI tools to the environment
    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      kubernetes-helm
      k9s # Terminal UI for Kubernetes
    ];

    # Ensure proper networking for Kubernetes
    networking = {
      firewall = {
        # Allow Kubernetes API server
        allowedTCPPorts = lib.mkIf (cfg.role == "server") [6443];

        # Allow internal cluster communication
        trustedInterfaces = ["cni0"];
      };

      # Proper kernel settings for k8s
      # kernel.sysctl = {
      #   "net.ipv4.ip_forward" = 1;
      #   "net.bridge.bridge-nf-call-iptables" = 1;
      #   "net.bridge.bridge-nf-call-ip6tables" = 1;
      # };
    };

    # Load required kernel modules
    boot.kernelModules = ["br_netfilter" "overlay"];

    # Setup system for running containers
    # boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;
    security.unprivilegedUsernsClone = true;
  };
}
