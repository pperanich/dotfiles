# Writing Flake-Parts Modules

## Module Anatomy

A flake-parts module is a Nix function that receives an attribute set and returns configuration:

```nix
{ config, lib, pkgs, inputs, self, ... }:
{
  # Options definitions
  options = { /* ... */ };

  # Configuration
  config = { /* ... */ };

  # Imports (if needed)
  imports = [ /* ... */ ];
}
```

## Module Arguments

### Standard Arguments

- **`config`**: The merged configuration (shared state)
- **`lib`**: Nixpkgs lib functions
- **`pkgs`**: Nixpkgs packages (system-specific)
- **`inputs`**: Flake inputs
- **`self`**: The flake itself
- **`system`**: Current system (e.g., "x86_64-linux")

### Usage Examples

```nix
{ config, lib, pkgs, inputs, ... }:
{
  config = {
    # Use pkgs to reference packages
    environment.systemPackages = [ pkgs.vim ];

    # Use lib for utilities
    programs.myapp.enable = lib.mkDefault true;

    # Access inputs
    nixpkgs.overlays = [ inputs.myoverlay.overlay ];

    # Read from config
    services.nginx.enable = config.myFeature.enable;
  };
}
```

## Options

### Defining Options

```nix
{ config, lib, ... }:
{
  options.myFeature = {
    enable = lib.mkEnableOption "my feature";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.myapp;
      description = "Package to use";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration";
    };
  };
}
```

### Common Option Types

- **`lib.types.bool`**: Boolean (true/false)
- **`lib.types.str`**: String
- **`lib.types.int`**: Integer
- **`lib.types.port`**: Port number (0-65535)
- **`lib.types.path`**: File path
- **`lib.types.package`**: Nix package
- **`lib.types.lines`**: Multi-line string
- **`lib.types.listOf <type>`**: List of type
- **`lib.types.attrsOf <type>`**: Attribute set of type
- **`lib.types.submodule { ... }`**: Nested module
- **`lib.types.either <type1> <type2>`**: One of two types
- **`lib.types.nullOr <type>`**: Type or null
- **`lib.types.enum [ ... ]`**: One of specified values

### Option Defaults

```nix
options.myFeature = {
  # Enable option (default false)
  enable = lib.mkEnableOption "my feature";

  # Default value
  timeout = lib.mkOption {
    type = lib.types.int;
    default = 30;
  };

  # No default (must be set by user)
  apiKey = lib.mkOption {
    type = lib.types.str;
    description = "API key for service";
  };
};
```

## Configuration

### Conditional Configuration

```nix
{ config, lib, ... }:
let
  cfg = config.myFeature;
in
{
  options.myFeature = {
    enable = lib.mkEnableOption "my feature";
  };

  config = lib.mkIf cfg.enable {
    # Only applied when myFeature.enable = true
    services.myservice.enable = true;
  };
}
```

### Multiple Conditions

```nix
{ config, lib, ... }:
{
  config = lib.mkMerge [
    # Always applied
    {
      environment.systemPackages = [ pkgs.base ];
    }

    # Conditional
    (lib.mkIf config.myFeature.enable {
      services.myservice.enable = true;
    })

    # Another condition
    (lib.mkIf config.myFeature.debug {
      services.myservice.logLevel = "debug";
    })
  ];
}
```

### Assertions

```nix
{ config, lib, ... }:
{
  config = {
    assertions = [
      {
        assertion = config.myFeature.enable -> config.services.database.enable;
        message = "myFeature requires database to be enabled";
      }
      {
        assertion = config.myFeature.port > 1024;
        message = "myFeature port must be > 1024 (unprivileged)";
      }
    ];
  };
}
```

## Accessing Other Modules

### Reading Options

```nix
{ config, lib, ... }:
{
  config = {
    # Read another module's option
    services.nginx.virtualHosts = lib.mkIf config.myFeature.enable {
      "example.com" = {
        locations."/" = {
          proxyPass = "http://localhost:${toString config.myFeature.port}";
        };
      };
    };
  };
}
```

### Writing to Shared State

```nix
{ config, lib, ... }:
{
  options.myFeature.overlays = lib.mkOption {
    type = lib.types.listOf lib.types.anything;
    default = [];
  };

  config.myFeature.overlays = [
    (final: prev: {
      mypackage = prev.mypackage.overrideAttrs (old: {
        version = "2.0";
      });
    })
  ];
}
```

## Flake-Level Outputs

### Defining Flake Outputs

```nix
{ config, lib, inputs, ... }:
{
  # Define a NixOS configuration
  flake.nixosConfigurations.myhost = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      # Include other modules
      config.myFeature.nixosModule
    ];
  };

  # Define a package
  flake.packages.x86_64-linux.myapp = pkgs.callPackage ./myapp.nix {};

  # Define a development shell
  flake.devShells.x86_64-linux.default = pkgs.mkShell {
    buildInputs = [ pkgs.myapp ];
  };
}
```

### Per-System Outputs

```nix
{ config, lib, ... }:
{
  perSystem = { config, pkgs, system, ... }: {
    # System-specific outputs
    packages.myapp = pkgs.callPackage ./myapp.nix {};

    devShells.default = pkgs.mkShell {
      buildInputs = [ config.packages.myapp ];
    };
  };
}
```

## Importing Other Modules

### Static Imports

```nix
{ config, lib, ... }:
{
  imports = [
    ./submodule.nix
    ./another-module.nix
  ];
}
```

### Conditional Imports

```nix
{ config, lib, ... }:
{
  imports = lib.optionals config.myFeature.enable [
    ./optional-module.nix
  ];
}
```

## Best Practices

### 1. Use Let Bindings

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myFeature;
  myPackage = pkgs.callPackage ./package.nix {};
in
{
  options.myFeature = { /* ... */ };
  config = lib.mkIf cfg.enable { /* ... */ };
}
```

### 2. Namespace Options

```nix
# Good: Namespaced
options.myFeature.subFeature.enable = ...;

# Bad: Flat namespace collision risk
options.subFeatureEnable = ...;
```

### 3. Document Options

```nix
options.myFeature.timeout = lib.mkOption {
  type = lib.types.int;
  default = 30;
  description = ''
    Timeout in seconds for connections.
    Set to 0 to disable timeout.
  '';
  example = 60;
};
```

### 4. Use Submodules for Complex Config

```nix
options.myFeature.instances = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "instance";
      port = lib.mkOption {
        type = lib.types.port;
        description = "Port for this instance";
      };
    };
  });
  default = {};
};

# Usage:
config.myFeature.instances.primary = {
  enable = true;
  port = 8080;
};
```

### 5. Validate Early

```nix
config = {
  assertions = [
    {
      assertion = cfg.enable -> cfg.apiKey != null;
      message = "myFeature.apiKey must be set when enabled";
    }
  ];

  warnings = lib.optional (cfg.debug) "myFeature.debug is enabled (not for production)";
};
```

## Common Patterns

### Enable Option with Config

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myFeature;
in
{
  options.myFeature = {
    enable = lib.mkEnableOption "my feature";
    package = lib.mkPackageOption pkgs "myapp" {};
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
```

### Dependency Management

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.myFeature.enable {
    # Ensure dependencies are enabled
    services.postgresql.enable = true;
    services.redis.enable = true;

    # Configure dependent service
    services.myapp = {
      enable = true;
      database = "postgres://localhost/mydb";
    };
  };
}
```

### Secrets Management

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myFeature;
in
{
  options.myFeature = {
    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing API key";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myapp = {
      serviceConfig = {
        LoadCredential = "apikey:${cfg.apiKeyFile}";
        ExecStart = "${pkgs.myapp}/bin/myapp --apikey-file=%d/apikey";
      };
    };
  };
}
```

## Testing Modules

### Assertions for Self-Tests

```nix
{ config, lib, ... }:
{
  config = {
    assertions = [
      {
        assertion = config.myFeature.port >= 1024;
        message = "Port must be >= 1024";
      }
    ];
  };
}
```

### NixOS Tests

```nix
# test.nix
{ pkgs, ... }:
pkgs.nixosTest {
  name = "myFeature-test";
  nodes.machine = { config, ... }: {
    imports = [ ./modules/myFeature.nix ];
    myFeature.enable = true;
  };
  testScript = ''
    machine.wait_for_unit("myapp.service")
    machine.succeed("curl http://localhost:8080")
  '';
}
```
