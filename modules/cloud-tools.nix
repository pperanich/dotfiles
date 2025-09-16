# Comprehensive cloud platform tools and infrastructure management
# Provides multi-cloud, Kubernetes, infrastructure-as-code, and monitoring tools
# Supports AWS, GCP, Azure, Kubernetes, Terraform, Pulumi, and more
_: {
  # NixOS system-level cloud tools and services
  flake.modules.nixos.cloudTools = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.cloudTools;
  in {
    options.features.cloudTools = {
      enableKubernetes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kubernetes cluster services (kubelet, etc.)";
      };

      enablePrometheus = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Prometheus monitoring service";
      };

      enableDockerRegistry = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable local Docker registry service";
      };

      terraformVersion = lib.mkOption {
        type = lib.types.str;
        default = "1.6";
        description = "Terraform version to use";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Additional cloud-related packages to install system-wide";
      };
    };

    config = {
      # System-level cloud platform tools
      environment.systemPackages = with pkgs;
        [
          # AWS tools
          awscli2
          aws-sam-cli
          aws-vault
          eksctl
          aws-iam-authenticator

          # Google Cloud tools
          google-cloud-sdk

          # Azure tools
          azure-cli
          azure-storage-azcopy

          # Kubernetes cluster tools
          kubectl
          helm
          k9s
          kubectx
          kubens
          kustomize
          kubernetes-helmPlugins.helm-diff
          kubernetes-helmPlugins.helm-s3
          kubernetes-helmPlugins.helm-git

          # Terraform and IaC
          terraform
          terragrunt
          tflint
          terraform-ls
          terraform-docs
          tfsec
          checkov

          # Infrastructure tools
          pulumi
          pulumi-bin
          ansible
          ansible-lint
          packer

          # Multi-cloud tools
          cloudflare-cli
          doctl # DigitalOcean
          linode-cli

          # Container registries
          skopeo
          crane
          dive
          cosign

          # Service mesh
          istioctl
          linkerd

          # Monitoring and observability
          prometheus
          grafana
          alertmanager
        ]
        ++ cfg.extraPackages;

      # Optional Kubernetes services
      services.kubernetes = lib.mkIf cfg.enableKubernetes {
        roles = ["master" "node"];
        masterAddress = "localhost";
        easyCerts = true;

        apiserver = {
          enable = true;
          advertiseAddress = "127.0.0.1";
        };

        controllerManager.enable = true;
        scheduler.enable = true;

        kubelet = {
          enable = true;
          extraOpts = "--fail-swap-on=false";
        };

        proxy.enable = true;
      };

      # Optional Prometheus monitoring
      services.prometheus = lib.mkIf cfg.enablePrometheus {
        enable = true;
        port = 9090;

        # Basic scrape configs
        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [
              {targets = ["localhost:9090"];}
            ];
          }
          {
            job_name = "node";
            static_configs = [
              {targets = ["localhost:9100"];}
            ];
          }
        ];
      };

      # Optional Docker registry
      services.dockerRegistry = lib.mkIf cfg.enableDockerRegistry {
        enable = true;
        port = 5000;
        listenAddress = "127.0.0.1";
      };

      # Firewall configuration for services
      networking.firewall.allowedTCPPorts = lib.mkMerge [
        (lib.mkIf cfg.enableKubernetes [
          6443 # Kubernetes API server
          2379
          2380 # etcd
          10250 # kubelet
          10251 # kube-scheduler
          10252 # kube-controller-manager
        ])
        (lib.mkIf cfg.enablePrometheus [
          9090 # Prometheus
          9100 # Node exporter
        ])
        (lib.mkIf cfg.enableDockerRegistry [
          5000 # Docker registry
        ])
      ];

      # Container runtime configuration
      virtualisation.podman.enable = lib.mkDefault true;
      virtualisation.podman.dockerCompat = lib.mkDefault true;

      # Enable container networking
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = lib.mkDefault 1;
        "net.bridge.bridge-nf-call-iptables" = lib.mkDefault 1;
      };

      # Users and groups for cloud operations
      users.groups.docker = {};
      users.users = lib.mkMerge [
        (lib.mapAttrs (name: user: {
            extraGroups = user.extraGroups or [] ++ ["docker"];
          })
          config.users.users)
      ];

      # System environment variables
      environment.variables = {
        # Kubernetes
        KUBECONFIG = lib.mkDefault "/etc/kubernetes/admin.conf";

        # Terraform
        TF_PLUGIN_CACHE_DIR = "/var/cache/terraform-plugins";

        # AWS
        AWS_DEFAULT_OUTPUT = lib.mkDefault "table";

        # Container tools
        BUILDKIT_HOST = lib.mkDefault "podman-container://buildkitd";
      };

      # Create cache directories
      system.activationScripts.cloud-tools-dirs = {
        text = ''
          mkdir -p /var/cache/terraform-plugins
          chmod 755 /var/cache/terraform-plugins
        '';
        deps = [];
      };
    };
  };

  # Darwin system-level cloud tools and native integrations
  flake.modules.darwin.cloudTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      # Core cloud platform tools
      awscli2
      aws-sam-cli
      aws-vault
      eksctl
      google-cloud-sdk
      azure-cli
      azure-storage-azcopy

      # Kubernetes tools
      kubectl
      helm
      k9s
      kubectx
      kubens
      kustomize
      kubernetes-helmPlugins.helm-diff

      # Infrastructure as Code
      terraform
      terragrunt
      tflint
      terraform-ls
      terraform-docs
      pulumi
      pulumi-bin
      ansible
      packer

      # Multi-cloud utilities
      cloudflare-cli
      doctl
      linode-cli

      # Container and registry tools
      skopeo
      crane
      dive
      cosign

      # Service mesh
      istioctl
      linkerd

      # Monitoring tools
      prometheus
    ];

    homebrew = {
      # GUI applications for cloud management
      casks = [
        "aws-vpn-client"
        "google-cloud-sdk"
        "azure-data-studio"
        "lens" # Kubernetes IDE
        "rancher"
        "docker" # Docker Desktop
        "podman-desktop"
        "grafana-agent"
        "terraform-docs"
        "session-manager-plugin"
      ];

      # Additional CLI tools via Homebrew
      brews = [
        "aws-sam-cli"
        "aws-shell"
        "awsume"
        "chamber" # AWS Parameter Store
        "cfn-lint"
        "copilot" # AWS Copilot
        "eksctl"
        "saml2aws"
        "azure-cli"
        "azure-functions-core-tools"
        "tfenv"
        "tgenv"
        "helm"
        "helmfile"
        "k6" # Load testing
        "grpcurl"
        "mongosh"
      ];

      # Homebrew taps for cloud tools
      taps = [
        "aws/tap"
        "azure/functions"
        "fairwindsops/tap"
        "grpc/grpc"
        "hashicorp/tap"
        "pulumi/tap"
      ];
    };

    # macOS-specific environment variables
    environment.variables = {
      # AWS configuration
      AWS_DEFAULT_OUTPUT = "table";
      AWS_PAGER = "";
      AWS_CLI_AUTO_PROMPT = "on-partial";

      # Google Cloud
      CLOUDSDK_PYTHON = "${pkgs.python3}/bin/python";

      # Kubernetes
      KUBE_EDITOR = "code --wait";

      # Terraform
      TF_PLUGIN_CACHE_DIR = "$HOME/.terraform.d/plugin-cache";

      # Container tools
      DOCKER_DEFAULT_PLATFORM = "linux/amd64";
    };

    # Launch agents for cloud services
    launchd.user.agents = {
      aws-vault-keychain = lib.mkIf false {
        # Disabled by default
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.aws-vault}/bin/aws-vault"
            "--backend=keychain"
            "daemon"
          ];
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
    };

    # System defaults for cloud development
    system.defaults = {
      # Dock preferences for cloud tools
      dock.persistent-apps = lib.mkBefore [
        "/Applications/Docker.app"
        "/Applications/Lens.app"
      ];

      # Finder preferences
      finder.FXPreferredViewStyle = "Nlsv"; # List view for better file management
    };
  };

  # Home Manager user-level cloud configuration and workflows
  flake.modules.homeModules.cloudTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # AWS ecosystem
        awscli2
        aws-sam-cli
        aws-vault
        eksctl
        aws-iam-authenticator
        chamber
        cfn-lint

        # Google Cloud Platform
        google-cloud-sdk

        # Microsoft Azure
        azure-cli
        azure-storage-azcopy

        # Kubernetes management
        kubectl
        helm
        k9s
        kubectx
        kubens
        kustomize
        kubernetes-helmPlugins.helm-diff
        kubernetes-helmPlugins.helm-s3
        kubernetes-helmPlugins.helm-git
        kubeseal
        krew

        # Infrastructure as Code
        terraform
        terragrunt
        tflint
        terraform-ls
        terraform-docs
        tfsec
        checkov
        infracost

        # Pulumi
        pulumi
        pulumi-bin

        # Configuration management
        ansible
        ansible-lint

        # Image building
        packer

        # Multi-cloud providers
        cloudflare-cli
        doctl # DigitalOcean
        linode-cli

        # Container registries and images
        skopeo
        crane
        dive
        cosign
        syft # SBOM generation

        # Service mesh tools
        istioctl
        linkerd

        # Monitoring and observability
        prometheus
        grafana-cli
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific cloud tools
        google-chrome # For web consoles
        firefox
        podman-desktop
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific tools handled via homebrew in darwin module
        awsume
        saml2aws
      ];

    # Cloud credential and configuration management
    home.file = {
      # AWS CLI configuration template
      ".aws/config.template" = {
        text = ''
          [default]
          region = us-west-2
          output = table
          cli_pager =
          cli_auto_prompt = on-partial

          [profile dev]
          region = us-west-2
          output = json

          [profile staging]
          region = us-west-2
          output = json

          [profile prod]
          region = us-west-2
          output = json
        '';
      };

      # Kubernetes config template
      ".kube/config.template" = {
        text = ''
          apiVersion: v1
          kind: Config
          current-context: ""
          contexts: []
          clusters: []
          users: []
        '';
      };

      # Cloud helper scripts
      ".local/bin/cloud-login" = {
        text = ''
          #!/usr/bin/env bash
          # Multi-cloud authentication helper
          set -euo pipefail

          show_help() {
            cat << EOF
          Cloud Login Helper

          Usage: cloud-login [OPTIONS] <provider> [profile/subscription]

          Providers:
            aws         AWS using aws-vault or native CLI
            azure       Azure using az login
            gcp         Google Cloud using gcloud auth
            k8s         Kubernetes using kubeconfig

          Options:
            -h, --help      Show this help
            -r, --refresh   Force refresh of credentials
            -v, --verbose   Verbose output

          Examples:
            cloud-login aws dev
            cloud-login azure my-subscription
            cloud-login gcp my-project
            cloud-login k8s my-cluster
          EOF
          }

          REFRESH=false
          VERBOSE=false

          # Parse arguments
          while [[ $# -gt 0 ]]; do
            case $1 in
              -h|--help)
                show_help
                exit 0
                ;;
              -r|--refresh)
                REFRESH=true
                shift
                ;;
              -v|--verbose)
                VERBOSE=true
                shift
                ;;
              aws|azure|gcp|k8s)
                PROVIDER="$1"
                shift
                ;;
              *)
                if [[ -z "''${PROVIDER:-}" ]]; then
                  echo "Error: Unknown provider: $1"
                  exit 1
                else
                  PROFILE="$1"
                fi
                shift
                ;;
            esac
          done

          if [[ -z "''${PROVIDER:-}" ]]; then
            echo "Error: Provider required"
            show_help
            exit 1
          fi

          # Verbose logging
          log() {
            if [[ "$VERBOSE" == true ]]; then
              echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
            fi
          }

          case $PROVIDER in
            aws)
              PROFILE="''${PROFILE:-default}"
              log "Logging into AWS profile: $PROFILE"

              if command -v aws-vault >/dev/null 2>&1; then
                if [[ "$REFRESH" == true ]]; then
                  aws-vault clear "$PROFILE"
                fi
                aws-vault exec "$PROFILE" -- aws sts get-caller-identity
                echo "export AWS_PROFILE=$PROFILE"
                echo "# Run: eval \$(cloud-login aws $PROFILE)"
              else
                export AWS_PROFILE="$PROFILE"
                aws sts get-caller-identity
              fi
              ;;

            azure)
              SUBSCRIPTION="''${PROFILE:-}"
              log "Logging into Azure"

              if [[ "$REFRESH" == true ]]; then
                az logout 2>/dev/null || true
              fi

              az login

              if [[ -n "$SUBSCRIPTION" ]]; then
                az account set --subscription "$SUBSCRIPTION"
              fi

              az account show
              ;;

            gcp)
              PROJECT="''${PROFILE:-}"
              log "Logging into Google Cloud"

              if [[ "$REFRESH" == true ]]; then
                gcloud auth revoke --all 2>/dev/null || true
              fi

              gcloud auth login --update-adc

              if [[ -n "$PROJECT" ]]; then
                gcloud config set project "$PROJECT"
              fi

              gcloud auth list
              gcloud config list
              ;;

            k8s)
              CONTEXT="''${PROFILE:-}"
              log "Switching Kubernetes context"

              if [[ -n "$CONTEXT" ]]; then
                kubectl config use-context "$CONTEXT"
              else
                kubectl config get-contexts
              fi

              kubectl config current-context
              kubectl cluster-info
              ;;

            *)
              echo "Unsupported provider: $PROVIDER"
              exit 1
              ;;
          esac
        '';
        executable = true;
      };

      # Infrastructure deployment helper
      ".local/bin/infra-deploy" = {
        text = ''
          #!/usr/bin/env bash
          # Infrastructure deployment helper
          set -euo pipefail

          show_help() {
            cat << EOF
          Infrastructure Deployment Helper

          Usage: infra-deploy [OPTIONS] <tool> <action> [target]

          Tools:
            terraform       Terraform deployment
            terragrunt      Terragrunt deployment
            pulumi          Pulumi deployment
            ansible         Ansible playbook
            kubectl         Kubernetes manifest

          Actions:
            plan            Show deployment plan
            apply           Apply deployment
            destroy         Destroy infrastructure
            validate        Validate configuration

          Options:
            -h, --help      Show this help
            -y, --yes       Auto-approve deployment
            -v, --verbose   Verbose output
            -d, --dry-run   Dry run mode

          Examples:
            infra-deploy terraform plan
            infra-deploy terragrunt apply --yes
            infra-deploy pulumi validate
            infra-deploy kubectl apply manifests/
          EOF
          }

          AUTO_APPROVE=false
          VERBOSE=false
          DRY_RUN=false

          # Parse arguments
          while [[ $# -gt 0 ]]; do
            case $1 in
              -h|--help)
                show_help
                exit 0
                ;;
              -y|--yes)
                AUTO_APPROVE=true
                shift
                ;;
              -v|--verbose)
                VERBOSE=true
                shift
                ;;
              -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
              terraform|terragrunt|pulumi|ansible|kubectl)
                TOOL="$1"
                shift
                ;;
              plan|apply|destroy|validate|up|down)
                ACTION="$1"
                shift
                ;;
              *)
                TARGET="$1"
                shift
                ;;
            esac
          done

          if [[ -z "''${TOOL:-}" ]] || [[ -z "''${ACTION:-}" ]]; then
            echo "Error: Tool and action required"
            show_help
            exit 1
          fi

          # Verbose logging
          log() {
            if [[ "$VERBOSE" == true ]]; then
              echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
            fi
          }

          # Confirmation prompt
          confirm() {
            if [[ "$AUTO_APPROVE" == true ]] || [[ "$DRY_RUN" == true ]]; then
              return 0
            fi

            read -p "Continue with $TOOL $ACTION? [y/N] " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]]
          }

          case $TOOL in
            terraform)
              log "Running Terraform $ACTION"

              case $ACTION in
                plan)
                  terraform plan "''${TARGET:+$TARGET}"
                  ;;
                apply)
                  terraform plan -out=tfplan "''${TARGET:+$TARGET}"
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      terraform apply tfplan
                    else
                      echo "DRY RUN: would run terraform apply tfplan"
                    fi
                  fi
                  ;;
                destroy)
                  terraform plan -destroy -out=tfplan "''${TARGET:+$TARGET}"
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      terraform apply tfplan
                    else
                      echo "DRY RUN: would run terraform apply tfplan"
                    fi
                  fi
                  ;;
                validate)
                  terraform validate
                  terraform fmt -check=true -diff=true
                  ;;
              esac
              ;;

            terragrunt)
              log "Running Terragrunt $ACTION"

              case $ACTION in
                plan)
                  terragrunt plan "''${TARGET:+$TARGET}"
                  ;;
                apply)
                  terragrunt plan "''${TARGET:+$TARGET}"
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      terragrunt apply "''${TARGET:+$TARGET}"
                    else
                      echo "DRY RUN: would run terragrunt apply"
                    fi
                  fi
                  ;;
                destroy)
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      terragrunt destroy "''${TARGET:+$TARGET}"
                    else
                      echo "DRY RUN: would run terragrunt destroy"
                    fi
                  fi
                  ;;
                validate)
                  terragrunt validate "''${TARGET:+$TARGET}"
                  ;;
              esac
              ;;

            pulumi)
              log "Running Pulumi $ACTION"

              case $ACTION in
                plan)
                  pulumi preview --diff
                  ;;
                apply|up)
                  pulumi preview --diff
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      pulumi up --yes
                    else
                      echo "DRY RUN: would run pulumi up"
                    fi
                  fi
                  ;;
                destroy|down)
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      pulumi destroy --yes
                    else
                      echo "DRY RUN: would run pulumi destroy"
                    fi
                  fi
                  ;;
                validate)
                  pulumi config
                  pulumi stack ls
                  ;;
              esac
              ;;

            ansible)
              log "Running Ansible $ACTION"
              TARGET="''${TARGET:-playbook.yml}"

              case $ACTION in
                plan)
                  ansible-playbook --check --diff "$TARGET"
                  ;;
                apply)
                  ansible-playbook --check --diff "$TARGET"
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      ansible-playbook "$TARGET"
                    else
                      echo "DRY RUN: would run ansible-playbook $TARGET"
                    fi
                  fi
                  ;;
                validate)
                  ansible-playbook --syntax-check "$TARGET"
                  ansible-lint "$TARGET" || true
                  ;;
              esac
              ;;

            kubectl)
              log "Running Kubernetes $ACTION"
              TARGET="''${TARGET:-.}"

              case $ACTION in
                plan)
                  kubectl diff -f "$TARGET" || true
                  ;;
                apply)
                  kubectl diff -f "$TARGET" || true
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      kubectl apply -f "$TARGET"
                    else
                      echo "DRY RUN: would run kubectl apply -f $TARGET"
                    fi
                  fi
                  ;;
                destroy)
                  if confirm; then
                    if [[ "$DRY_RUN" == false ]]; then
                      kubectl delete -f "$TARGET"
                    else
                      echo "DRY RUN: would run kubectl delete -f $TARGET"
                    fi
                  fi
                  ;;
                validate)
                  kubectl apply --dry-run=client -f "$TARGET"
                  kubectl apply --dry-run=server -f "$TARGET"
                  ;;
              esac
              ;;
          esac
        '';
        executable = true;
      };

      # Cloud cost monitoring helper
      ".local/bin/cloud-costs" = {
        text = ''
          #!/usr/bin/env bash
          # Cloud cost monitoring helper
          set -euo pipefail

          show_help() {
            cat << EOF
          Cloud Cost Monitoring Helper

          Usage: cloud-costs [OPTIONS] <provider> [timeframe]

          Providers:
            aws         AWS Cost Explorer
            azure       Azure Cost Management
            gcp         Google Cloud Billing

          Timeframes:
            today       Today's costs
            week        This week
            month       This month (default)
            last-month  Previous month

          Options:
            -h, --help      Show this help
            -d, --detailed  Show detailed breakdown
            -f, --format    Output format (table, json, csv)

          Examples:
            cloud-costs aws month
            cloud-costs azure --detailed
            cloud-costs gcp week --format json
          EOF
          }

          DETAILED=false
          FORMAT="table"
          TIMEFRAME="month"

          # Parse arguments
          while [[ $# -gt 0 ]]; do
            case $1 in
              -h|--help)
                show_help
                exit 0
                ;;
              -d|--detailed)
                DETAILED=true
                shift
                ;;
              -f|--format)
                FORMAT="$2"
                shift 2
                ;;
              aws|azure|gcp)
                PROVIDER="$1"
                shift
                ;;
              today|week|month|last-month)
                TIMEFRAME="$1"
                shift
                ;;
              *)
                echo "Unknown option: $1"
                shift
                ;;
            esac
          done

          if [[ -z "''${PROVIDER:-}" ]]; then
            echo "Error: Provider required"
            show_help
            exit 1
          fi

          # Calculate date ranges
          case $TIMEFRAME in
            today)
              START_DATE=$(date +%Y-%m-%d)
              END_DATE=$(date +%Y-%m-%d)
              ;;
            week)
              START_DATE=$(date -d 'monday' +%Y-%m-%d)
              END_DATE=$(date +%Y-%m-%d)
              ;;
            month)
              START_DATE=$(date +%Y-%m-01)
              END_DATE=$(date +%Y-%m-%d)
              ;;
            last-month)
              START_DATE=$(date -d 'last month' +%Y-%m-01)
              END_DATE=$(date -d 'last month' +%Y-%m-%d)
              ;;
          esac

          case $PROVIDER in
            aws)
              echo "AWS costs for $TIMEFRAME ($START_DATE to $END_DATE):"

              if [[ "$DETAILED" == true ]]; then
                aws ce get-cost-and-usage \
                  --time-period Start="$START_DATE",End="$END_DATE" \
                  --granularity DAILY \
                  --metrics BlendedCost \
                  --group-by Type=DIMENSION,Key=SERVICE \
                  --output "$FORMAT"
              else
                aws ce get-cost-and-usage \
                  --time-period Start="$START_DATE",End="$END_DATE" \
                  --granularity MONTHLY \
                  --metrics BlendedCost \
                  --output "$FORMAT"
              fi
              ;;

            azure)
              echo "Azure costs for $TIMEFRAME:"

              SUBSCRIPTION_ID=$(az account show --query id -o tsv)

              if [[ "$DETAILED" == true ]]; then
                az consumption usage list \
                  --start-date "$START_DATE" \
                  --end-date "$END_DATE" \
                  --output "$FORMAT"
              else
                az billing account show \
                  --account-name "$SUBSCRIPTION_ID" \
                  --output "$FORMAT"
              fi
              ;;

            gcp)
              echo "GCP costs for $TIMEFRAME:"

              PROJECT_ID=$(gcloud config get-value project)

              if [[ "$DETAILED" == true ]]; then
                gcloud billing budgets list \
                  --billing-account="$(gcloud alpha billing accounts list --format='value(name)' --limit=1)" \
                  --format="$FORMAT"
              else
                echo "GCP cost details require Cloud Billing API setup"
                echo "Project: $PROJECT_ID"
                echo "Use: gcloud billing accounts list"
              fi
              ;;
          esac
        '';
        executable = true;
      };
    };

    # Shell integration for cloud tools
    programs.bash = {
      shellAliases = {
        # AWS shortcuts
        "aws-whoami" = "aws sts get-caller-identity";
        "aws-regions" = "aws ec2 describe-regions --query 'Regions[].RegionName' --output table";
        "aws-profiles" = "aws configure list-profiles";

        # Kubernetes shortcuts
        "k" = "kubectl";
        "kgp" = "kubectl get pods";
        "kgs" = "kubectl get services";
        "kgd" = "kubectl get deployments";
        "kctx" = "kubectx";
        "kns" = "kubens";

        # Terraform shortcuts
        "tf" = "terraform";
        "tg" = "terragrunt";
        "tfp" = "terraform plan";
        "tfa" = "terraform apply";
        "tfd" = "terraform destroy";

        # Cloud login shortcuts
        "aws-login" = "cloud-login aws";
        "az-login" = "cloud-login azure";
        "gcp-login" = "cloud-login gcp";
      };

      initExtra = ''
        # AWS vault integration
        if command -v aws-vault >/dev/null 2>&1; then
          complete -C aws-vault aws-vault
        fi

        # Kubernetes completion
        if command -v kubectl >/dev/null 2>&1; then
          source <(kubectl completion bash)
          complete -F __start_kubectl k
        fi

        # Helm completion
        if command -v helm >/dev/null 2>&1; then
          source <(helm completion bash)
        fi

        # Terraform completion
        if command -v terraform >/dev/null 2>&1; then
          complete -C terraform terraform
          complete -C terraform tf
        fi

        # Cloud platform context switcher
        cloud_context() {
          echo "Current cloud contexts:"
          echo "AWS Profile: ''${AWS_PROFILE:-default}"
          echo "Azure Subscription: $(az account show --query name -o tsv 2>/dev/null || echo 'Not logged in')"
          echo "GCP Project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
          echo "Kubernetes Context: $(kubectl config current-context 2>/dev/null || echo 'None')"
        }

        # Infrastructure deployment wrapper
        deploy() {
          local tool="''${1:-terraform}"
          local action="''${2:-plan}"
          shift 2 || true
          infra-deploy "$tool" "$action" "$@"
        }
      '';
    };

    programs.zsh = {
      shellAliases = {
        # AWS shortcuts
        "aws-whoami" = "aws sts get-caller-identity";
        "aws-regions" = "aws ec2 describe-regions --query 'Regions[].RegionName' --output table";
        "aws-profiles" = "aws configure list-profiles";

        # Kubernetes shortcuts
        "k" = "kubectl";
        "kgp" = "kubectl get pods";
        "kgs" = "kubectl get services";
        "kgd" = "kubectl get deployments";
        "kctx" = "kubectx";
        "kns" = "kubens";

        # Terraform shortcuts
        "tf" = "terraform";
        "tg" = "terragrunt";
        "tfp" = "terraform plan";
        "tfa" = "terraform apply";
        "tfd" = "terraform destroy";

        # Cloud login shortcuts
        "aws-login" = "cloud-login aws";
        "az-login" = "cloud-login azure";
        "gcp-login" = "cloud-login gcp";
      };

      initExtra = ''
        # AWS vault integration
        if command -v aws-vault >/dev/null 2>&1; then
          eval "$(aws-vault --completion-script-zsh)"
        fi

        # Kubernetes completion
        if command -v kubectl >/dev/null 2>&1; then
          source <(kubectl completion zsh)
          compdef __start_kubectl k
        fi

        # Helm completion
        if command -v helm >/dev/null 2>&1; then
          source <(helm completion zsh)
        fi

        # Terraform completion
        if command -v terraform >/dev/null 2>&1; then
          complete -o nospace -C terraform terraform
          complete -o nospace -C terraform tf
        fi

        # Cloud platform context switcher
        cloud_context() {
          echo "Current cloud contexts:"
          echo "AWS Profile: ''${AWS_PROFILE:-default}"
          echo "Azure Subscription: $(az account show --query name -o tsv 2>/dev/null || echo 'Not logged in')"
          echo "GCP Project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
          echo "Kubernetes Context: $(kubectl config current-context 2>/dev/null || echo 'None')"
        }

        # Infrastructure deployment wrapper
        deploy() {
          local tool="''${1:-terraform}"
          local action="''${2:-plan}"
          shift 2 || true
          infra-deploy "$tool" "$action" "$@"
        }

        # Kubernetes context switching with fzf (if available)
        if command -v fzf >/dev/null 2>&1; then
          kctx-fzf() {
            local context
            context=$(kubectl config get-contexts -o name | fzf --prompt="Select Kubernetes context: ")
            if [[ -n "$context" ]]; then
              kubectl config use-context "$context"
            fi
          }

          kns-fzf() {
            local namespace
            namespace=$(kubectl get namespaces -o name | cut -d/ -f2 | fzf --prompt="Select namespace: ")
            if [[ -n "$namespace" ]]; then
              kubectl config set-context --current --namespace="$namespace"
            fi
          }
        fi
      '';
    };

    # Environment variables for cloud development
    home.sessionVariables = {
      # AWS configuration
      AWS_DEFAULT_OUTPUT = "table";
      AWS_CLI_AUTO_PROMPT = "on-partial";
      AWS_PAGER = "";

      # Azure configuration
      AZURE_CONFIG_DIR = "$HOME/.azure";

      # Google Cloud configuration
      CLOUDSDK_CONFIG = "$HOME/.config/gcloud";
      CLOUDSDK_PYTHON = "${pkgs.python3}/bin/python";

      # Kubernetes configuration
      KUBECONFIG = "$HOME/.kube/config";
      KUBE_EDITOR = "vim";

      # Terraform configuration
      TF_PLUGIN_CACHE_DIR = "$HOME/.terraform.d/plugin-cache";
      TF_CLI_CONFIG_FILE = "$HOME/.terraformrc";

      # Ansible configuration
      ANSIBLE_CONFIG = "$HOME/.ansible.cfg";
      ANSIBLE_INVENTORY = "$HOME/.ansible/inventory";

      # Container configuration
      DOCKER_CONFIG = "$HOME/.docker";
      BUILDKIT_HOST = "podman-container://buildkitd";

      # Monitoring
      PROMETHEUS_CONFIG = "$HOME/.config/prometheus";
    };

    # XDG configuration files for cloud tools
    xdg.configFile = {
      # AWS CLI configuration
      "aws/cli/alias" = {
        text = ''
          [toplevel]

          whoami = sts get-caller-identity
          regions = ec2 describe-regions --query 'Regions[].RegionName' --output table
          azs = ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output table
          instances = ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table

          # EKS shortcuts
          eks-clusters = eks list-clusters --query 'clusters' --output table
          eks-update-kubeconfig = !f() { aws eks update-kubeconfig --region $1 --name $2; }; f
        '';
      };

      # Kubernetes k9s configuration
      "k9s/config.yaml" = {
        text = ''
          k9s:
            refreshRate: 2
            maxConnRetry: 5
            readOnly: false
            noExitOnCtrlC: false
            ui:
              enableMouse: false
              headless: false
              logoless: false
              crumbsless: false
              reactive: false
              noIcons: false
            skipLatestRevCheck: false
            disablePodCounting: false
            shellPod:
              image: busybox:1.35.0
              namespace: default
              limits:
                cpu: 100m
                memory: 100Mi
            imageScans:
              enable: false
              exclusions:
                namespaces: []
                labels: {}
            logger:
              tail: 100
              buffer: 5000
              sinceSeconds: -1
              fullScreenLogs: false
              textWrap: false
              showTime: false
            thresholds:
              cpu:
                critical: 90
                warn: 70
              memory:
                critical: 90
                warn: 70
        '';
      };

      # Terraform CLI configuration
      "terraform/config.tfrc" = {
        text = ''
          plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
          disable_checkpoint = true
        '';
      };

      # Ansible configuration
      "ansible/ansible.cfg" = {
        text = ''
          [defaults]
          host_key_checking = False
          retry_files_enabled = False
          gathering = smart
          fact_caching = memory
          stdout_callback = yaml
          callbacks_enabled = profile_tasks, timer

          [inventory]
          enable_plugins = aws_ec2, gcp_compute, azure_rm

          [ssh_connection]
          ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s
          pipelining = True
        '';
      };

      # Prometheus configuration
      "prometheus/prometheus.yml" = {
        text = ''
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          rule_files: []

          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

            - job_name: 'node'
              static_configs:
                - targets: ['localhost:9100']
        '';
      };
    };

    # VSCode extensions for cloud development (if VSCode is enabled)
    programs.vscode = lib.mkIf (config.programs.vscode.enable or false) {
      extensions = with pkgs.vscode-extensions; [
        # AWS extensions
        amazonwebservices.aws-toolkit-vscode

        # Azure extensions
        ms-azuretools.vscode-azureresourcegroups
        ms-azuretools.vscode-azurestorage
        ms-azuretools.vscode-azurefunctions

        # Kubernetes extensions
        ms-kubernetes-tools.vscode-kubernetes-tools

        # Terraform extensions
        hashicorp.terraform

        # Docker extensions
        ms-azuretools.vscode-docker

        # Infrastructure as Code
        ms-vscode.vscode-json
        redhat.vscode-yaml
      ];

      userSettings = {
        # AWS Toolkit settings
        "aws.profile" = "default";
        "aws.region" = "us-west-2";

        # Kubernetes settings
        "vs-kubernetes.kubectl-path" = "${pkgs.kubectl}/bin/kubectl";
        "vs-kubernetes.helm-path" = "${pkgs.helm}/bin/helm";

        # Terraform settings
        "terraform.languageServer.enable" = true;
        "terraform.experimentalFeatures.validateOnSave" = true;

        # YAML settings for Kubernetes manifests
        "yaml.schemas" = {
          "kubernetes" = "*.k8s.yaml";
        };
      };
    };

    # Git configuration for cloud infrastructure repositories
    programs.git.extraConfig = {
      # Infrastructure-specific settings
      includeIf."gitdir:**/infrastructure/**" = {
        path = "~/.config/git/config-infra";
      };
      includeIf."gitdir:**/terraform/**" = {
        path = "~/.config/git/config-infra";
      };
      includeIf."gitdir:**/ansible/**" = {
        path = "~/.config/git/config-infra";
      };
    };

    # Infrastructure-specific Git configuration
    xdg.configFile."git/config-infra" = {
      text = ''
        [core]
          autocrlf = false
          eol = lf

        [diff "terraform"]
          textconv = terraform fmt -diff -

        [merge "terraform"]
          name = terraform fmt merge driver
          driver = terraform fmt -write %A

        [alias]
          tf-plan = !terraform plan
          tf-apply = !terraform apply
          tf-fmt = !terraform fmt -recursive .
      '';
    };

    # Create necessary directories
    home.activation = {
      createCloudDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p $HOME/.terraform.d/plugin-cache
        $DRY_RUN_CMD mkdir -p $HOME/.kube
        $DRY_RUN_CMD mkdir -p $HOME/.aws
        $DRY_RUN_CMD mkdir -p $HOME/.azure
        $DRY_RUN_CMD mkdir -p $HOME/.config/gcloud
        $DRY_RUN_CMD mkdir -p $HOME/.ansible
        $DRY_RUN_CMD mkdir -p $HOME/.local/bin
      '';
    };
  };
}
