#!/usr/bin/env python3
"""
Assign workspaces to monitors based on declarative layout configuration.
Reads from workspace-layouts.toml to determine assignments.
"""

import subprocess
import json
import sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib

SCRIPT_DIR = Path(__file__).parent
CONFIG_FILE = SCRIPT_DIR / "workspace-layouts.toml"
AEROSPACE = "/opt/homebrew/bin/aerospace"


def get_connected_monitors():
    """Get currently connected monitors with their serial numbers."""
    # Get aerospace monitor info
    aero = subprocess.run(
        [AEROSPACE, "list-monitors", "--format", "%{monitor-id}|%{monitor-name}|%{monitor-is-main}"],
        capture_output=True,
        text=True,
    )
    aero_monitors = []
    for line in aero.stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split("|")
        if len(parts) >= 3:
            aero_monitors.append({"id": parts[0], "name": parts[1], "is_main": parts[2] == "true"})

    # Get serial numbers from system_profiler
    result = subprocess.run(
        ["system_profiler", "SPDisplaysDataType", "-json"],
        capture_output=True,
        text=True,
    )
    data = json.loads(result.stdout)

    monitors = {}
    sys_displays = []

    for gpu in data.get("SPDisplaysDataType", []):
        for disp in gpu.get("spdisplays_ndrvs", []):
            name = disp.get("_name", "")
            serial_hex = disp.get("_spdisplays_display-serial-number", "")
            is_main = disp.get("spdisplays_main", "") == "spdisplays_yes"
            is_builtin = disp.get("spdisplays_connection_type", "") == "spdisplays_internal"
            try:
                serial = str(int(serial_hex, 16)) if serial_hex else ""
            except ValueError:
                serial = serial_hex
            sys_displays.append(
                {"name": name, "serial": serial, "is_main": is_main, "is_builtin": is_builtin}
            )

    # Match system displays with aerospace monitors
    used_aero = set()
    for sys_disp in sys_displays:
        matched_aero = None

        if sys_disp["is_builtin"] or "Color LCD" in sys_disp["name"]:
            # Match built-in
            for aero in aero_monitors:
                if "Built-in" in aero["name"] and aero["id"] not in used_aero:
                    matched_aero = aero
                    break
        else:
            # Match external by main status first
            for aero in aero_monitors:
                if aero["id"] not in used_aero and "DELL" in aero["name"]:
                    if aero["is_main"] == sys_disp["is_main"]:
                        matched_aero = aero
                        break

            # Fallback: any unmatched external
            if not matched_aero:
                for aero in aero_monitors:
                    if aero["id"] not in used_aero and aero["name"] not in ["Built-in Retina Display"]:
                        matched_aero = aero
                        break

        if matched_aero:
            used_aero.add(matched_aero["id"])
            monitors[sys_disp["serial"]] = {
                "id": matched_aero["id"],
                "name": matched_aero["name"],
                "is_main": matched_aero["is_main"],
                "is_builtin": sys_disp["is_builtin"],
            }

    return monitors


def find_matching_layout(config, connected_serials):
    """Find the best matching layout for current monitor configuration."""
    layouts = config.get("layouts", [])

    # Sort by priority (descending)
    layouts = sorted(layouts, key=lambda x: x.get("priority", 0), reverse=True)

    for layout in layouts:
        requires = set(layout.get("requires", []))
        excludes = set(layout.get("excludes", []))

        # Check if all required monitors are present
        if not requires.issubset(connected_serials):
            continue

        # Check if no excluded monitors are present
        if excludes.intersection(connected_serials):
            continue

        return layout

    return None


def apply_layout(layout, monitors):
    """Apply workspace assignments from layout."""
    assignments = layout.get("assignments", {})

    # Find main, secondary (non-main external), and builtin monitors
    main_id = None
    secondary_id = None
    builtin_id = None

    for serial, info in monitors.items():
        if info["is_builtin"]:
            builtin_id = info["id"]
        elif info["is_main"]:
            main_id = info["id"]
        else:
            # Non-main, non-builtin = secondary external
            secondary_id = info["id"]

    print(f"Applying layout: {layout.get('name', 'unnamed')}")
    print(f"  main={main_id}, secondary={secondary_id}, builtin={builtin_id}")
    print("")

    for workspace, target in assignments.items():
        workspace = str(workspace)

        # Resolve target to monitor-id
        if target == "main":
            monitor_id = main_id
        elif target == "secondary":
            monitor_id = secondary_id
        elif target == "builtin":
            monitor_id = builtin_id
        elif target in monitors:
            monitor_id = monitors[target]["id"]
        else:
            print(f"  Warning: Unknown target '{target}' for workspace {workspace}")
            continue

        if monitor_id:
            result = subprocess.run(
                [AEROSPACE, "move-workspace-to-monitor", "--workspace", workspace, monitor_id],
                capture_output=True,
                text=True,
            )
            status = "OK" if result.returncode == 0 else "FAIL"
            print(f"  Workspace {workspace} -> monitor {monitor_id}: {status}")
        else:
            print(f"  Workspace {workspace}: target '{target}' not available")


def trigger_sketchybar_update():
    """Trigger sketchybar to update workspace display."""
    try:
        focused = subprocess.run(
            [AEROSPACE, "list-workspaces", "--focused"],
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["sketchybar", "--trigger", "aerospace_workspace_change",
             f"FOCUSED_WORKSPACE={focused.stdout.strip()}"],
            capture_output=True,
        )
    except Exception:
        pass


def main():
    print("=== Workspace-to-Monitor Assignment ===")
    print("")

    if not CONFIG_FILE.exists():
        print(f"Error: Config file not found: {CONFIG_FILE}")
        sys.exit(1)

    # Load config
    with open(CONFIG_FILE, "rb") as f:
        config = tomllib.load(f)

    # Get connected monitors
    monitors = get_connected_monitors()
    connected_serials = set(monitors.keys())

    print("Connected monitors:")
    for serial, info in monitors.items():
        main_str = " (main)" if info["is_main"] else ""
        builtin_str = " [builtin]" if info["is_builtin"] else ""
        print(f"  {info['name']}: serial={serial}, id={info['id']}{main_str}{builtin_str}")
    print("")

    # Find matching layout
    layout = find_matching_layout(config, connected_serials)

    if layout:
        apply_layout(layout, monitors)
    else:
        print("No matching layout found for current monitor configuration")
        print("Using fallback: all workspaces to main monitor")
        for ws in range(1, 9):
            subprocess.run(
                [AEROSPACE, "move-workspace-to-monitor", "--workspace", str(ws), "main"],
                capture_output=True,
            )

    print("")
    print("=== Assignment complete ===")

    trigger_sketchybar_update()


if __name__ == "__main__":
    main()
