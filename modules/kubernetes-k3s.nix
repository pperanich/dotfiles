# Kubernetes K3S lightweight distribution module
# Provides comprehensive K3S cluster setup and management tools
# Supports server/agent roles, cluster networking, and kubectl integration
_: {
  # NixOS system-level K3S service and cluster configuration
  flake.modules.nixos.kubernetesK3s = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.kubernetesK3s;
  in {
    options.features.kubernetesK3s = {
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

      networking = {
        clusterCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.42.0.0/16";
          description = "CIDR range for cluster pods";
        };

        serviceCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.43.0.0/16";
          description = "CIDR range for cluster services";
        };

        enableIPv6 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable IPv6 dual-stack networking";
        };
      };

      storage = {
        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/rancher/k3s";
          description = "Directory for K3S data";
        };

        enableEtcdBackup = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable automated etcd snapshots";
        };

        backupRetention = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Number of etcd snapshots to retain";
        };
      };
    };

    config = {
      # Core K3S service configuration
      services.k3s = {
        enable = true;
        inherit (cfg) role;
        serverAddr = lib.mkIf (cfg.role == "agent") cfg.serverAddr;
        inherit (cfg) token;

        # Configure extra arguments based on role
        extraFlags = let
          commonArgs =
            [
              "--cluster-cidr=${cfg.networking.clusterCidr}"
              "--service-cidr=${cfg.networking.serviceCidr}"
              "--data-dir=${cfg.storage.dataDir}"
            ]
            ++ lib.optionals cfg.networking.enableIPv6 [
              "--cluster-init"
              "--dual-stack"
            ];

          serverArgs =
            commonArgs
            ++ [
              "--write-kubeconfig-mode=644"
            ]
            ++ lib.optionals cfg.enableLocalStorage [
              "--disable=local-storage=false"
            ]
            ++ lib.optionals cfg.storage.enableEtcdBackup [
              "--etcd-snapshot-retention=${toString cfg.storage.backupRetention}"
              "--etcd-snapshot-schedule-cron=0 */12 * * *"
            ]
            ++ cfg.extraServerArgs;

          agentArgs = commonArgs ++ cfg.extraAgentArgs;
        in
          if cfg.role == "server"
          then serverArgs
          else agentArgs;
      };

      # System packages for K3S and Kubernetes management
      environment.systemPackages = with pkgs; [
        # Core K3S and Kubernetes tools
        k3s
        kubectl
        kubernetes-helm

        # Cluster management and monitoring
        k9s
        kubectx
        kubens
        kustomize

        # Container and image management
        cri-tools
        buildah
        skopeo

        # Network debugging and analysis
        tcpdump
        wireshark-cli
        netcat
      ];

      # Network configuration for K3S cluster
      networking = {
        firewall = {
          # Server node ports
          allowedTCPPorts = lib.mkIf (cfg.role == "server") [
            6443 # Kubernetes API server
            10250 # Kubelet metrics
          ];

          # Allow internal cluster communication
          trustedInterfaces = ["cni0" "flannel.1"];

          # Allow cluster pod-to-pod communication
          extraCommands = ''
            # Allow traffic from cluster CIDR
            iptables -A INPUT -s ${cfg.networking.clusterCidr} -j ACCEPT
            iptables -A INPUT -s ${cfg.networking.serviceCidr} -j ACCEPT
          '';
        };

        # Network bridge configuration for containers
        bridges.cni0.interfaces = [];
      };

      # Kernel configuration for container networking
      boot = {
        # Required kernel modules for K3S
        kernelModules = [
          "br_netfilter"
          "overlay"
          "xt_CHECKSUM"
          "xt_MASQUERADE"
          "iptable_nat"
          "ip_tables"
        ];

        # Kernel parameters for optimal container performance
        kernel.sysctl = {
          # Enable IP forwarding
          "net.ipv4.ip_forward" = 1;
          "net.ipv6.conf.all.forwarding" = lib.mkIf cfg.networking.enableIPv6 1;

          # Bridge netfilter settings
          "net.bridge.bridge-nf-call-iptables" = 1;
          "net.bridge.bridge-nf-call-ip6tables" = 1;
          "net.bridge.bridge-nf-call-arptables" = 1;

          # Container networking optimizations
          "net.netfilter.nf_conntrack_max" = 131072;
          "net.core.rmem_max" = 134217728;
          "net.core.wmem_max" = 134217728;
        };
      };

      # Security configuration
      security = {
        # Enable unprivileged user namespaces for containers
        unprivilegedUsernsClone = true;

        # AppArmor profiles for container security
        apparmor = {
          enable = true;
          packages = [pkgs.apparmor-profiles];
        };
      };

      # System users and groups for K3S
      users.groups.k3s = {};
      users.users.k3s = {
        isSystemUser = true;
        group = "k3s";
        home = cfg.storage.dataDir;
        createHome = true;
      };

      # Systemd service enhancements
      systemd.services.k3s = {
        # Service dependencies
        wants = ["network-online.target"];
        after = ["network-online.target"];

        # Environment variables
        environment = {
          K3S_KUBECONFIG_OUTPUT = "/etc/rancher/k3s/k3s.yaml";
          K3S_KUBECONFIG_MODE = "644";
        };

        # Service hardening
        serviceConfig = {
          # Resource limits
          LimitNOFILE = 1048576;
          LimitNPROC = 1048576;
          LimitCORE = "infinity";
          TasksMax = "infinity";

          # Security settings
          KillMode = "mixed";
          Delegate = "yes";
          Type = "notify";
          NotifyAccess = "all";
        };
      };

      # Automatic cleanup service for container images
      systemd.services.k3s-cleanup = {
        description = "K3S container image cleanup";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.k3s}/bin/k3s crictl rmi --prune";
          User = "root";
        };
      };

      systemd.timers.k3s-cleanup = {
        description = "Run K3S cleanup weekly";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
      };
    };
  };

  # Darwin system-level K3S tools (K3S doesn't run natively on macOS)
  flake.modules.darwin.kubernetesK3s = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      # Kubernetes client tools
      kubectl
      kubernetes-helm
      k9s
      kubectx
      kubens
      kustomize

      # Container tools for working with K3S clusters
      docker
      colima # Docker runtime for macOS

      # Remote cluster management
      lens
      kubespy
      stern
    ];

    # macOS-specific configuration for remote K3S management
    environment.variables = {
      KUBECONFIG = "$HOME/.kube/config";
      KUBE_EDITOR = "code --wait";
    };

    # Homebrew packages for additional tools
    homebrew = {
      casks = [
        "lens"
        "docker"
      ];

      brews = [
        "derailed/k9s/k9s"
        "helm"
        "skaffold"
        "kind" # For local testing
      ];
    };
  };

  # Home Manager user-level K3S and Kubernetes configuration
  flake.modules.homeModules.kubernetesK3s = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Essential Kubernetes tools
        kubectl
        kubernetes-helm
        k9s
        kubectx
        kubens
        kustomize

        # Development and debugging tools
        stern
        kubespy
        kubeshark
        kubesec

        # Manifest management
        kustomize
        yq-go

        # Container image tools
        skopeo
        dive
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        cri-tools
        buildah
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages
        colima
      ];

    # Kubectl configuration and aliases
    programs.bash.shellAliases = {
      # Kubectl shortcuts
      "k" = "kubectl";
      "kgp" = "kubectl get pods";
      "kgs" = "kubectl get services";
      "kgd" = "kubectl get deployments";
      "kgn" = "kubectl get nodes";
      "kga" = "kubectl get all";

      # Namespace management
      "kns" = "kubens";
      "kctx" = "kubectx";

      # Resource management
      "kdel" = "kubectl delete";
      "kdes" = "kubectl describe";
      "klog" = "kubectl logs";
      "kexec" = "kubectl exec -it";

      # Cluster operations
      "ktop" = "kubectl top";
      "kpf" = "kubectl port-forward";
      "kroll" = "kubectl rollout";

      # K3S specific
      "k3s-reset" = "sudo k3s-killall.sh && sudo k3s-uninstall.sh";
      "k3s-logs" = "sudo journalctl -u k3s -f";
    };

    programs.zsh.shellAliases = {
      # Kubectl shortcuts
      "k" = "kubectl";
      "kgp" = "kubectl get pods";
      "kgs" = "kubectl get services";
      "kgd" = "kubectl get deployments";
      "kgn" = "kubectl get nodes";
      "kga" = "kubectl get all";

      # Namespace management
      "kns" = "kubens";
      "kctx" = "kubectx";

      # Resource management
      "kdel" = "kubectl delete";
      "kdes" = "kubectl describe";
      "klog" = "kubectl logs";
      "kexec" = "kubectl exec -it";

      # Cluster operations
      "ktop" = "kubectl top";
      "kpf" = "kubectl port-forward";
      "kroll" = "kubectl rollout";

      # K3S specific
      "k3s-reset" = "sudo k3s-killall.sh && sudo k3s-uninstall.sh";
      "k3s-logs" = "sudo journalctl -u k3s -f";
    };

    # Kubectl configuration
    xdg.configFile = {
      # Default kubectl config structure
      "k3s/kubeconfig.yaml" = {
        text = ''
          # K3S kubeconfig template
          # This file will be populated by K3S server
          apiVersion: v1
          kind: Config
          preferences: {}
          clusters: []
          contexts: []
          users: []
        '';
      };

      # Kubernetes resource templates
      "kubernetes/templates/deployment.yaml" = {
        text = ''
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: example-app
            labels:
              app: example-app
          spec:
            replicas: 3
            selector:
              matchLabels:
                app: example-app
            template:
              metadata:
                labels:
                  app: example-app
              spec:
                containers:
                - name: app
                  image: nginx:alpine
                  ports:
                  - containerPort: 80
                  resources:
                    requests:
                      memory: "64Mi"
                      cpu: "250m"
                    limits:
                      memory: "128Mi"
                      cpu: "500m"
        '';
      };

      "kubernetes/templates/service.yaml" = {
        text = ''
          apiVersion: v1
          kind: Service
          metadata:
            name: example-service
            labels:
              app: example-app
          spec:
            type: ClusterIP
            ports:
            - port: 80
              targetPort: 80
              protocol: TCP
              name: http
            selector:
              app: example-app
        '';
      };

      "kubernetes/templates/ingress.yaml" = {
        text = ''
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: example-ingress
            annotations:
              kubernetes.io/ingress.class: "traefik"
          spec:
            rules:
            - host: example.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: example-service
                      port:
                        number: 80
        '';
      };
    };

    # Helper scripts for K3S management
    home.file.".local/bin/k3s-cluster-info" = {
      text = ''
        #!/usr/bin/env bash
        # K3S cluster information display
        set -euo pipefail

        echo "=== K3S Cluster Information ==="
        echo

        # Check if kubectl is available
        if ! command -v kubectl >/dev/null 2>&1; then
          echo "kubectl not available"
          exit 1
        fi

        # Check cluster connectivity
        echo "📡 Cluster Status:"
        if kubectl cluster-info >/dev/null 2>&1; then
          kubectl cluster-info
          echo
        else
          echo "❌ Cannot connect to cluster"
          exit 1
        fi

        # Node information
        echo "🖥️  Nodes:"
        kubectl get nodes -o wide
        echo

        # Namespace overview
        echo "📁 Namespaces:"
        kubectl get namespaces
        echo

        # System pods
        echo "⚙️  System Pods:"
        kubectl get pods -n kube-system
        echo

        # Resource usage
        echo "📊 Resource Usage:"
        kubectl top nodes 2>/dev/null || echo "Metrics not available"
        echo

        # Storage classes
        echo "💾 Storage Classes:"
        kubectl get storageclass
        echo

        # Services overview
        echo "🌐 Services:"
        kubectl get services --all-namespaces
      '';
      executable = true;
    };

    home.file.".local/bin/k3s-deploy-app" = {
      text = ''
        #!/usr/bin/env bash
        # Deploy application to K3S cluster
        set -euo pipefail

        show_help() {
          cat << EOF
        K3S Application Deployment Helper

        Usage: k3s-deploy-app [OPTIONS] <app-name>

        Options:
          -h, --help          Show this help
          -i, --image         Container image (default: nginx:alpine)
          -p, --port          Container port (default: 80)
          -r, --replicas      Number of replicas (default: 3)
          -n, --namespace     Kubernetes namespace (default: default)
          --expose            Create service and ingress
          --domain            Domain for ingress (default: <app-name>.local)

        Examples:
          k3s-deploy-app my-app
          k3s-deploy-app -i redis:alpine -p 6379 redis-cache
          k3s-deploy-app --expose --domain app.example.com web-app
        EOF
        }

        # Default values
        IMAGE="nginx:alpine"
        PORT="80"
        REPLICAS="3"
        NAMESPACE="default"
        EXPOSE=false
        DOMAIN=""

        # Parse arguments
        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help)
              show_help
              exit 0
              ;;
            -i|--image)
              IMAGE="$2"
              shift 2
              ;;
            -p|--port)
              PORT="$2"
              shift 2
              ;;
            -r|--replicas)
              REPLICAS="$2"
              shift 2
              ;;
            -n|--namespace)
              NAMESPACE="$2"
              shift 2
              ;;
            --expose)
              EXPOSE=true
              shift
              ;;
            --domain)
              DOMAIN="$2"
              shift 2
              ;;
            *)
              if [[ -z "''${APP_NAME:-}" ]]; then
                APP_NAME="$1"
              else
                echo "Error: Unknown argument: $1"
                exit 1
              fi
              shift
              ;;
          esac
        done

        if [[ -z "''${APP_NAME:-}" ]]; then
          echo "Error: Application name required"
          show_help
          exit 1
        fi

        # Set default domain if exposing
        if [[ "$EXPOSE" == true && -z "$DOMAIN" ]]; then
          DOMAIN="''${APP_NAME}.local"
        fi

        echo "Deploying $APP_NAME to K3S cluster..."

        # Create namespace if it doesn't exist
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

        # Create deployment
        cat << EOF | kubectl apply -f -
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: $APP_NAME
          namespace: $NAMESPACE
          labels:
            app: $APP_NAME
        spec:
          replicas: $REPLICAS
          selector:
            matchLabels:
              app: $APP_NAME
          template:
            metadata:
              labels:
                app: $APP_NAME
            spec:
              containers:
              - name: $APP_NAME
                image: $IMAGE
                ports:
                - containerPort: $PORT
                resources:
                  requests:
                    memory: "64Mi"
                    cpu: "250m"
                  limits:
                    memory: "128Mi"
                    cpu: "500m"
        EOF

        # Create service if exposing
        if [[ "$EXPOSE" == true ]]; then
          cat << EOF | kubectl apply -f -
          apiVersion: v1
          kind: Service
          metadata:
            name: $APP_NAME
            namespace: $NAMESPACE
            labels:
              app: $APP_NAME
          spec:
            type: ClusterIP
            ports:
            - port: 80
              targetPort: $PORT
              protocol: TCP
              name: http
            selector:
              app: $APP_NAME
        EOF

          # Create ingress
          cat << EOF | kubectl apply -f -
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: $APP_NAME
            namespace: $NAMESPACE
            annotations:
              kubernetes.io/ingress.class: "traefik"
          spec:
            rules:
            - host: $DOMAIN
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: $APP_NAME
                      port:
                        number: 80
        EOF

          echo "✅ Application deployed and exposed at http://$DOMAIN"
        else
          echo "✅ Application deployed"
        fi

        echo
        echo "📊 Deployment status:"
        kubectl get deployment "$APP_NAME" -n "$NAMESPACE"

        echo
        echo "🔍 To check pods:"
        echo "kubectl get pods -n $NAMESPACE -l app=$APP_NAME"

        if [[ "$EXPOSE" == true ]]; then
          echo
          echo "🌐 Add to /etc/hosts for local access:"
          echo "127.0.0.1 $DOMAIN"
        fi
      '';
      executable = true;
    };

    # Environment variables for Kubernetes
    home.sessionVariables = {
      KUBECONFIG = "$HOME/.kube/config";
      KUBE_EDITOR = lib.mkDefault "nano";
      K3S_KUBECONFIG_MODE = "644";
    };

    # Shell integration for kubectl
    programs.bash.initExtra = ''
      # Kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion bash)
      fi

      # Helm completion
      if command -v helm >/dev/null 2>&1; then
        source <(helm completion bash)
      fi

      # K3S cluster context switcher
      k3s_ctx() {
        local context="''${1:-}"
        if [[ -z "$context" ]]; then
          kubectl config get-contexts
        else
          kubectl config use-context "$context"
        fi
      }
    '';

    programs.zsh.initExtra = ''
      # Kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion zsh)
      fi

      # Helm completion
      if command -v helm >/dev/null 2>&1; then
        source <(helm completion zsh)
      fi

      # K3S cluster context switcher
      k3s_ctx() {
        local context="''${1:-}"
        if [[ -z "$context" ]]; then
          kubectl config get-contexts
        else
          kubectl config use-context "$context"
        fi
      }
    '';
  };
}
