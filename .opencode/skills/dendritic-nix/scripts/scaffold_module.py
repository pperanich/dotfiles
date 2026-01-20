#!/usr/bin/env python3
"""
Generate a new dendritic flake-parts module with proper structure.

Creates a module file with the standard flake-parts pattern,
including config, options, and proper module structure.
"""

import argparse
import sys
from pathlib import Path


def get_module_template(module_name: str, module_type: str) -> str:
    """Generate module template based on type."""

    if module_type == "simple":
        return f'''{{ config, lib, pkgs, ... }}:
{{
  # {module_name} module
  # Simple module that configures a specific feature

  # Add your configuration here
  # Example: enable a service, install packages, set options
}}
'''

    elif module_type == "with-options":
        option_name = module_name.replace("-", "_")
        return f'''{{ config, lib, pkgs, ... }}:
let
  cfg = config.{option_name};
in
{{
  options.{option_name} = {{
    enable = lib.mkEnableOption "{module_name}";

    # Add more options here
    # Example:
    # package = lib.mkOption {{
    #   type = lib.types.package;
    #   default = pkgs.{module_name};
    #   description = "Package to use for {module_name}";
    # }};
  }};

  config = lib.mkIf cfg.enable {{
    # Add your configuration here that applies when enabled
  }};
}}
'''

    elif module_type == "cross-platform":
        return f'''{{ config, lib, pkgs, ... }}:
{{
  # {module_name} module
  # Configures feature across NixOS, home-manager, and nix-darwin

  # NixOS configuration
  # nixosConfigurations.hostname.config = {{ ... }};

  # home-manager configuration
  # home-manager.users.username = {{ ... }};

  # nix-darwin configuration (macOS)
  # darwinConfigurations.hostname.config = {{ ... }};

  # Add platform-specific configuration as needed
}}
'''

    elif module_type == "flake-module":
        return f'''{{ config, lib, ... }}:
{{
  # {module_name} flake-level module
  # Configures flake-level outputs and options

  # Set flake options
  # config.flake.nixosConfigurations.hostname = {{ ... }};

  # Or define custom flake options
  # options.flake.{module_name.replace("-", "_")} = {{ ... }};
}}
'''

    return ""


def create_module(path: Path, module_name: str, module_type: str, force: bool = False):
    """Create a new module file."""

    # Ensure parent directory exists
    path.parent.mkdir(parents=True, exist_ok=True)

    # Check if file already exists
    if path.exists() and not force:
        print(f"Error: {path} already exists. Use --force to overwrite.", file=sys.stderr)
        sys.exit(1)

    # Generate and write template
    template = get_module_template(module_name, module_type)
    path.write_text(template)

    print(f"✅ Created module: {path}")
    print(f"\nNext steps:")
    print(f"1. Edit {path} to add your configuration")
    print(f"2. The module will be auto-imported by flake-parts")
    print(f"3. Run 'nix flake check' to validate")


def main():
    parser = argparse.ArgumentParser(
        description="Generate a new dendritic flake-parts module"
    )
    parser.add_argument(
        "name",
        help="Module name (e.g., 'ssh-config', 'vim', 'networking/vpn')"
    )
    parser.add_argument(
        "-t", "--type",
        choices=["simple", "with-options", "cross-platform", "flake-module"],
        default="simple",
        help="Module type (default: simple)"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output path (default: modules/<name>.nix)"
    )
    parser.add_argument(
        "-f", "--force",
        action="store_true",
        help="Overwrite existing file"
    )

    args = parser.parse_args()

    # Determine output path
    if args.output:
        output_path = Path(args.output)
    else:
        # Default to modules/<name>.nix
        output_path = Path("modules") / f"{args.name}.nix"

    # Extract module name from path
    module_name = output_path.stem

    create_module(output_path, module_name, args.type, args.force)


if __name__ == "__main__":
    main()
