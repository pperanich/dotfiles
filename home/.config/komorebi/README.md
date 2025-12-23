# komorebi Configuration

This directory contains configuration for [komorebi](https://github.com/LGUG2Z/komorebi), a tiling window manager for Windows.

## Files

- `komorebi.json` - Main komorebi configuration
- `komorebi.bar.json` - Status bar configuration (komorebi-bar)
- `applications.yaml` - Application-specific configurations (downloaded automatically)

## Configuration Overview

### Workspaces

10 workspaces configured to match macOS setup:

1. **1-mail** - Email clients (Outlook)
2. **2-slack** - Messaging apps (Slack, Teams)
3. **3-web** - Web browsers (Chrome, Edge, Firefox, Brave)
4. **4-term** - Terminals (Windows Terminal, PowerShell, Alacritty)
5. **5-ide** - Code editors (VSCode, Visual Studio, IntelliJ)
6. **6-notes** - Note-taking apps (OneNote, Notion, Obsidian)
7. **7-zoom** - Video conferencing (Zoom, Teams)
8. **8-social** - Social/messaging (Discord, Element)
9. **9** - General purpose
10. **10** - General purpose

### Layout

- Default layout: **BSP** (Binary Space Partitioning)
- Window padding: 6px (workspace and container)
- Border width: 8px
- Mouse follows focus: Enabled

### Window Rules

#### Float Rules (by title substring)

- Settings windows
- Preferences windows
- Properties windows
- Task Manager

#### Workspace Assignments (by executable name)

Applications automatically open in their designated workspaces. See `komorebi.json` for the full list.

## Customization

### Adding Application Rules

To assign an application to a specific workspace:

```json
{
  "exe": "YourApp.exe",
  "workspace": 0 // 0-indexed (0 = workspace 1)
}
```

Find the executable name using PowerShell:

```powershell
Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object ProcessName, MainWindowTitle
```

### Changing Workspace Names

Edit the `monitors[0].workspaces` array in `komorebi.json`:

```json
{
  "name": "custom-name",
  "layout": "BSP"
}
```

### Adding Float Rules

To make windows float by default:

```json
{
  "kind": "Title", // or "Class" or "Exe"
  "id": "window-title", // substring to match
  "matching_strategy": "Substring" // or "Equals"
}
```

### Adjusting Gaps and Padding

```json
{
  "default_workspace_padding": 6, // Space around edges
  "default_container_padding": 6 // Space between windows
}
```

## Keybindings

Keybindings are configured in `~/.config/whkd/whkdrc`. See that directory's README for details.

Key highlights:

- **Win + 1-9/0**: Switch to workspace
- **Alt + H/J/K/L**: Focus window (vim-style)
- **Alt + Shift + H/J/K/L**: Move window
- **Alt + Shift + 1-9**: Move window to workspace

## Application-Specific Configuration

The `applications.yaml` file contains rules for applications that don't behave well with tiling window managers.

To update this file:

```powershell
komorebic fetch-asc
```

This downloads the community-maintained list from:
https://github.com/LGUG2Z/komorebi-application-specific-configuration

## Status Bar (komorebi-bar)

The `komorebi.bar.json` file configures the status bar that displays at the top of your screen.

### Widgets Configured

**Left side:**

- Workspace indicators (shows all 10 workspaces)
- Layout indicator (BSP, Stack, etc.)
- Focused window (shows current app icon and title)

**Right side:**

- Media widget (shows currently playing music/video)
- CPU usage
- Network status
- Battery indicator
- Date
- Time (24-hour format)

### Theme

The status bar uses the **Catppuccin Mocha** theme to match the macOS SketchyBar configuration.

### Starting with Status Bar

To start komorebi with the status bar:

```powershell
komorebic start --whkd --bar
```

To reload bar configuration:

```powershell
komorebic bar-config reload
```

### Customizing the Bar

Edit `komorebi.bar.json` to:

- Change the theme/colors
- Enable/disable specific widgets
- Adjust widget order
- Change date/time formats
- Configure widget refresh intervals

## Reloading Configuration

After editing `komorebi.json`:

```powershell
komorebic reload-configuration
```

Or use the keyboard shortcut: **Alt + Shift + R**

## Troubleshooting

### Logs

Logs are stored in: `%LOCALAPPDATA%\komorebi\komorebi.log`

### Restore Hidden Windows

If windows get stuck hidden:

```powershell
komorebic restore-windows
```

### Known Window Handles

List of known windows: `%LOCALAPPDATA%\komorebi\komorebi.hwnd.json`

### Disable komorebi for Specific Apps

Add to `float_rules` or use:

```powershell
komorebic float-rule title "App Name"
```

## Resources

- [komorebi Documentation](https://lgug2z.github.io/komorebi/)
- [komorebi GitHub](https://github.com/LGUG2Z/komorebi)
- [Configuration Schema](https://komorebi.lgug2z.com/schema)
- [Discord Community](https://discord.gg/mGkn66PHkx)

## Integration with Dotfiles

This configuration is managed as part of the dotfiles repository. On Windows:

- **With admin**: Configs are symlinked from dotfiles
- **Without admin**: Configs are copied from dotfiles

To update from dotfiles, re-run the installation script:

```powershell
.\bin\install-windows-wm.ps1
```
