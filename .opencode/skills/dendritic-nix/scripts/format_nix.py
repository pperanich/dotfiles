#!/usr/bin/env python3
"""
Format Nix files using available formatters.

Tries formatters in order: treefmt, nixpkgs-fmt, alejandra, nixfmt.
Falls back to the next formatter if one is not available.
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import List, Optional


class NixFormatter:
    def __init__(self):
        self.available_formatters = self.detect_formatters()

    def detect_formatters(self) -> List[str]:
        """Detect available Nix formatters."""
        formatters = ["treefmt", "nixpkgs-fmt", "alejandra", "nixfmt"]
        available = []

        for formatter in formatters:
            try:
                subprocess.run(
                    [formatter, "--help"],
                    capture_output=True,
                    check=False,
                    timeout=5
                )
                available.append(formatter)
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue

        return available

    def format_with_treefmt(self, paths: List[Path]) -> bool:
        """Format using treefmt (respects treefmt.toml config)."""
        try:
            result = subprocess.run(
                ["treefmt"] + [str(p) for p in paths],
                capture_output=True,
                text=True,
                timeout=60
            )
            if result.returncode != 0:
                print(result.stderr, file=sys.stderr)
                return False
            print(result.stdout)
            return True
        except subprocess.TimeoutExpired:
            print("Error: treefmt timed out", file=sys.stderr)
            return False

    def format_with_nixpkgs_fmt(self, paths: List[Path]) -> bool:
        """Format using nixpkgs-fmt."""
        try:
            result = subprocess.run(
                ["nixpkgs-fmt"] + [str(p) for p in paths],
                capture_output=True,
                text=True,
                timeout=60
            )
            if result.returncode != 0:
                print(result.stderr, file=sys.stderr)
                return False
            print(result.stdout)
            return True
        except subprocess.TimeoutExpired:
            print("Error: nixpkgs-fmt timed out", file=sys.stderr)
            return False

    def format_with_alejandra(self, paths: List[Path]) -> bool:
        """Format using alejandra."""
        try:
            result = subprocess.run(
                ["alejandra"] + [str(p) for p in paths],
                capture_output=True,
                text=True,
                timeout=60
            )
            if result.returncode != 0:
                print(result.stderr, file=sys.stderr)
                return False
            print(result.stdout)
            return True
        except subprocess.TimeoutExpired:
            print("Error: alejandra timed out", file=sys.stderr)
            return False

    def format_with_nixfmt(self, paths: List[Path]) -> bool:
        """Format using nixfmt."""
        try:
            result = subprocess.run(
                ["nixfmt"] + [str(p) for p in paths],
                capture_output=True,
                text=True,
                timeout=60
            )
            if result.returncode != 0:
                print(result.stderr, file=sys.stderr)
                return False
            print(result.stdout)
            return True
        except subprocess.TimeoutExpired:
            print("Error: nixfmt timed out", file=sys.stderr)
            return False

    def format(self, paths: List[Path], formatter: Optional[str] = None) -> bool:
        """Format Nix files using specified or auto-detected formatter."""
        if not self.available_formatters:
            print("Error: No Nix formatters found. Install treefmt, nixpkgs-fmt, alejandra, or nixfmt.", file=sys.stderr)
            return False

        # Use specified formatter or first available
        selected_formatter = formatter if formatter else self.available_formatters[0]

        if selected_formatter not in self.available_formatters:
            print(f"Error: {selected_formatter} not available. Available: {', '.join(self.available_formatters)}", file=sys.stderr)
            return False

        print(f"Formatting with {selected_formatter}...")

        if selected_formatter == "treefmt":
            return self.format_with_treefmt(paths)
        elif selected_formatter == "nixpkgs-fmt":
            return self.format_with_nixpkgs_fmt(paths)
        elif selected_formatter == "alejandra":
            return self.format_with_alejandra(paths)
        elif selected_formatter == "nixfmt":
            return self.format_with_nixfmt(paths)

        return False


def main():
    parser = argparse.ArgumentParser(
        description="Format Nix files using available formatters"
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Paths to format (files or directories)"
    )
    parser.add_argument(
        "-f", "--formatter",
        choices=["treefmt", "nixpkgs-fmt", "alejandra", "nixfmt"],
        help="Specific formatter to use"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check if files are formatted without modifying"
    )

    args = parser.parse_args()

    # Default to current directory if no paths specified
    paths = [Path(p) for p in args.paths] if args.paths else [Path(".")]

    # Expand directories to .nix files
    nix_files = []
    for path in paths:
        if path.is_file() and path.suffix == ".nix":
            nix_files.append(path)
        elif path.is_dir():
            nix_files.extend(path.rglob("*.nix"))

    if not nix_files:
        print("No .nix files found to format.")
        return

    formatter = NixFormatter()
    success = formatter.format(nix_files, args.formatter)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
