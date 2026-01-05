#!/usr/bin/env python3
"""
Lightweight Nix package and option search utility.

Simplified from mcp-nixos for direct command-line use without MCP overhead.
Searches NixOS packages, options, home-manager options, and nix-darwin options.
"""

import argparse
import json
import sys
from typing import Dict, List, Optional
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
import urllib.parse


def search_nixos_packages(query: str, channel: str = "unstable", limit: int = 10) -> List[Dict]:
    """Search NixOS packages using the search.nixos.org API."""
    base_url = "https://search.nixos.org/backend/latest-42-nixos-unstable/_search"

    # Build Elasticsearch query
    es_query = {
        "from": 0,
        "size": limit,
        "query": {
            "bool": {
                "must": [
                    {
                        "dis_max": {
                            "queries": [
                                {"wildcard": {"package_attr_name": {"value": f"*{query}*", "case_insensitive": True}}},
                                {"wildcard": {"package_pname": {"value": f"*{query}*", "case_insensitive": True}}},
                                {"wildcard": {"package_description": {"value": f"*{query}*", "case_insensitive": True}}}
                            ]
                        }
                    }
                ]
            }
        }
    }

    try:
        req = Request(
            base_url,
            data=json.dumps(es_query).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            hits = data.get('hits', {}).get('hits', [])

            results = []
            for hit in hits:
                source = hit.get('_source', {})
                results.append({
                    'name': source.get('package_attr_name', 'N/A'),
                    'pname': source.get('package_pname', 'N/A'),
                    'version': source.get('package_pversion', 'N/A'),
                    'description': source.get('package_description', 'N/A')[:200]
                })
            return results
    except (URLError, HTTPError) as e:
        print(f"Error searching packages: {e}", file=sys.stderr)
        return []


def search_nixos_options(query: str, channel: str = "unstable", limit: int = 10) -> List[Dict]:
    """Search NixOS options using the search.nixos.org API."""
    base_url = "https://search.nixos.org/backend/latest-42-nixos-unstable/_search"

    es_query = {
        "from": 0,
        "size": limit,
        "query": {
            "bool": {
                "must": [
                    {
                        "dis_max": {
                            "queries": [
                                {"wildcard": {"option_name": {"value": f"*{query}*", "case_insensitive": True}}},
                                {"wildcard": {"option_description": {"value": f"*{query}*", "case_insensitive": True}}}
                            ]
                        }
                    }
                ]
            }
        }
    }

    try:
        req = Request(
            base_url,
            data=json.dumps(es_query).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            hits = data.get('hits', {}).get('hits', [])

            results = []
            for hit in hits:
                source = hit.get('_source', {})
                results.append({
                    'name': source.get('option_name', 'N/A'),
                    'type': source.get('option_type', 'N/A'),
                    'default': source.get('option_default', 'N/A'),
                    'description': source.get('option_description', 'N/A')[:200]
                })
            return results
    except (URLError, HTTPError) as e:
        print(f"Error searching options: {e}", file=sys.stderr)
        return []


def format_results(results: List[Dict], result_type: str) -> str:
    """Format search results for display."""
    if not results:
        return f"No {result_type} found."

    output = []
    for i, result in enumerate(results, 1):
        if result_type == "packages":
            output.append(f"{i}. {result['name']} ({result['version']})")
            output.append(f"   {result['description']}")
        elif result_type == "options":
            output.append(f"{i}. {result['name']}")
            output.append(f"   Type: {result['type']}")
            if result['default'] != 'N/A':
                output.append(f"   Default: {result['default']}")
            output.append(f"   {result['description']}")
        output.append("")

    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description="Search NixOS packages and options"
    )
    parser.add_argument("query", help="Search query")
    parser.add_argument(
        "-t", "--type",
        choices=["packages", "options", "both"],
        default="both",
        help="Type of search to perform"
    )
    parser.add_argument(
        "-c", "--channel",
        default="unstable",
        help="NixOS channel to search"
    )
    parser.add_argument(
        "-l", "--limit",
        type=int,
        default=10,
        help="Maximum number of results"
    )
    parser.add_argument(
        "-j", "--json",
        action="store_true",
        help="Output results as JSON"
    )

    args = parser.parse_args()

    all_results = {}

    if args.type in ["packages", "both"]:
        packages = search_nixos_packages(args.query, args.channel, args.limit)
        all_results["packages"] = packages

    if args.type in ["options", "both"]:
        options = search_nixos_options(args.query, args.channel, args.limit)
        all_results["options"] = options

    if args.json:
        print(json.dumps(all_results, indent=2))
    else:
        if "packages" in all_results:
            print("=== PACKAGES ===")
            print(format_results(all_results["packages"], "packages"))

        if "options" in all_results:
            print("=== OPTIONS ===")
            print(format_results(all_results["options"], "options"))


if __name__ == "__main__":
    main()
