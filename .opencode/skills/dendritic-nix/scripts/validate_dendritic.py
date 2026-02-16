#!/usr/bin/env python3
"""
Validate a Nix flake follows dendritic pattern conventions.

Checks:
- All .nix files are flake-parts modules
- Directory structure follows conventions
- No hardcoded imports (files should be auto-imported)
- Proper use of config/options pattern
- Warning about specialArgs anti-patterns
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple


class DendriticValidator:
    def __init__(self, flake_path: Path):
        self.flake_path = flake_path
        self.errors = []
        self.warnings = []

    def validate(self) -> bool:
        """Run all validation checks."""
        self.check_flake_exists()
        self.check_nix_files_are_modules()
        self.check_no_hardcoded_imports()
        self.check_specialargs_usage()
        self.check_file_naming()

        return len(self.errors) == 0

    def check_flake_exists(self):
        """Check that flake.nix exists."""
        flake_file = self.flake_path / "flake.nix"
        if not flake_file.exists():
            self.errors.append(f"No flake.nix found at {self.flake_path}")

    def check_nix_files_are_modules(self):
        """Check that .nix files follow flake-parts module pattern."""
        for nix_file in self.flake_path.rglob("*.nix"):
            # Skip flake.nix itself
            if nix_file.name == "flake.nix":
                continue

            # Skip files starting with underscore (excluded from imports)
            if nix_file.name.startswith("_"):
                continue

            content = nix_file.read_text()

            # Check if file looks like a flake-parts module
            # Should have { config, lib, ... }: or similar pattern
            if not re.search(r'\{\s*(?:config|lib|pkgs|inputs)', content):
                self.warnings.append(
                    f"{nix_file.relative_to(self.flake_path)}: "
                    "Doesn't appear to be a flake-parts module (missing config/lib/pkgs/inputs args)"
                )

    def check_no_hardcoded_imports(self):
        """Check for hardcoded import statements."""
        for nix_file in self.flake_path.rglob("*.nix"):
            content = nix_file.read_text()

            # Look for import statements with hardcoded paths
            import_matches = re.finditer(r'import\s+\./', content)
            for match in import_matches:
                self.warnings.append(
                    f"{nix_file.relative_to(self.flake_path)}: "
                    f"Contains hardcoded import at position {match.start()}. "
                    "Dendritic pattern prefers auto-discovery."
                )

    def check_specialargs_usage(self):
        """Warn about specialArgs usage (anti-pattern in dendritic)."""
        for nix_file in self.flake_path.rglob("*.nix"):
            content = nix_file.read_text()

            if "specialArgs" in content or "extraSpecialArgs" in content:
                self.warnings.append(
                    f"{nix_file.relative_to(self.flake_path)}: "
                    "Uses specialArgs/extraSpecialArgs. Consider using flake-parts config instead."
                )

    def check_file_naming(self):
        """Check file naming conventions."""
        for nix_file in self.flake_path.rglob("*.nix"):
            if nix_file.name == "flake.nix":
                continue

            # Warn about files with uppercase letters (convention is lowercase)
            if any(c.isupper() for c in nix_file.name):
                self.warnings.append(
                    f"{nix_file.relative_to(self.flake_path)}: "
                    "Contains uppercase letters. Dendritic convention prefers lowercase with hyphens."
                )

    def print_report(self):
        """Print validation report."""
        if self.errors:
            print("❌ ERRORS:", file=sys.stderr)
            for error in self.errors:
                print(f"  • {error}", file=sys.stderr)
            print()

        if self.warnings:
            print("⚠️  WARNINGS:")
            for warning in self.warnings:
                print(f"  • {warning}")
            print()

        if not self.errors and not self.warnings:
            print("✅ All checks passed! Flake follows dendritic conventions.")
        elif not self.errors:
            print("✅ No critical errors, but see warnings above.")
        else:
            print("❌ Validation failed. Fix errors before proceeding.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Validate a Nix flake follows dendritic pattern conventions"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Path to the flake directory (default: current directory)"
    )

    args = parser.parse_args()
    flake_path = Path(args.path).resolve()

    validator = DendriticValidator(flake_path)
    success = validator.validate()
    validator.print_report()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
