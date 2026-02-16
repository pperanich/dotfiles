# whkd Configuration

This directory contains configuration for [whkd](https://github.com/LGUG2Z/whkd), a hotkey daemon for Windows.

## Files

- `whkdrc` - Hotkey bindings configuration

## Overview

The keybindings in this configuration closely mirror the macOS AeroSpace/SKHD setup with appropriate key translations for Windows.

### Key Translation Philosophy

| macOS Key | Windows Key | Usage                 |
| --------- | ----------- | --------------------- |
| Cmd       | Win         | Workspace switching   |
| Alt       | Alt         | Window focus/movement |
| Ctrl      | Ctrl        | Advanced operations   |

This provides consistent muscle memory across macOS and Windows environments.

## Keybinding Reference

### System Commands

| Keybinding               | Action                               |
| ------------------------ | ------------------------------------ |
| `Alt + Shift + O`        | Reload whkd configuration            |
| `Alt + Shift + R`        | Reload komorebi configuration        |
| `Alt + Ctrl + Shift + R` | Retile all windows                   |
| `Alt + P`                | Toggle pause (stop managing windows) |

### Window Focus (Vim-style + Arrows)

| Keybinding                | Action               |
| ------------------------- | -------------------- |
| `Alt + H` / `Alt + Left`  | Focus left window    |
| `Alt + J` / `Alt + Down`  | Focus down window    |
| `Alt + K` / `Alt + Up`    | Focus up window      |
| `Alt + L` / `Alt + Right` | Focus right window   |
| `Alt + Shift + [`         | Cycle focus previous |
| `Alt + Shift + ]`         | Cycle focus next     |

### Window Movement

| Keybinding                                | Action                          |
| ----------------------------------------- | ------------------------------- |
| `Alt + Shift + H` / `Alt + Shift + Left`  | Move window left                |
| `Alt + Shift + J` / `Alt + Shift + Down`  | Move window down                |
| `Alt + Shift + K` / `Alt + Shift + Up`    | Move window up                  |
| `Alt + Shift + L` / `Alt + Shift + Right` | Move window right               |
| `Alt + Shift + Enter`                     | Promote window to main position |

### Stack Windows

| Keybinding             | Action                    |
| ---------------------- | ------------------------- |
| `Alt + Ctrl + H/J/K/L` | Stack window in direction |
| `Alt + ;`              | Unstack window            |
| `Alt + [`              | Cycle stack previous      |
| `Alt + ]`              | Cycle stack next          |

### Resize Windows

| Keybinding        | Action                   |
| ----------------- | ------------------------ |
| `Alt + =`         | Increase horizontal size |
| `Alt + -`         | Decrease horizontal size |
| `Alt + Shift + =` | Increase vertical size   |
| `Alt + Shift + -` | Decrease vertical size   |

### Window State

| Keybinding            | Action                     |
| --------------------- | -------------------------- |
| `Alt + T`             | Toggle float               |
| `Alt + Shift + Space` | Toggle float (alternative) |
| `Alt + F`             | Toggle maximize/fullscreen |
| `Alt + Shift + F`     | Toggle monocle mode        |
| `Alt + W`             | Close window               |
| `Alt + M`             | Minimize window            |

### Layout Management

| Keybinding        | Action                   |
| ----------------- | ------------------------ |
| `Alt + E`         | Set BSP layout           |
| `Alt + R`         | Toggle float mode        |
| `Alt + /`         | Cycle through layouts    |
| `Alt + X`         | Flip layout horizontally |
| `Alt + Y`         | Flip layout vertically   |
| `Alt + Shift + 0` | Equalize/balance windows |

### Workspace Navigation (Win key)

| Keybinding                  | Action                             |
| --------------------------- | ---------------------------------- |
| `Win + 1` through `Win + 9` | Switch to workspace 1-9            |
| `Win + 0`                   | Switch to workspace 10             |
| `Win + Left`                | Previous workspace                 |
| `Win + Right`               | Next workspace                     |
| `Alt + B`                   | Back-and-forth to recent workspace |

### Move Window to Workspace

| Keybinding                          | Action                       |
| ----------------------------------- | ---------------------------- |
| `Alt + Shift + 1` through `Alt + 9` | Move window to workspace 1-9 |
| `Alt + Shift + B`                   | Move to recent workspace     |

### Monitor Management

| Keybinding                   | Action                         |
| ---------------------------- | ------------------------------ |
| `Alt + Ctrl + 1/2/3`         | Focus monitor 1/2/3            |
| `Alt + Ctrl + X`             | Next monitor                   |
| `Alt + Ctrl + Z`             | Previous monitor               |
| `Alt + Shift + Ctrl + 1/2/3` | Move window to monitor 1/2/3   |
| `Alt + Shift + Tab`          | Move workspace to next monitor |

## Customization

### Adding Custom Keybindings

Add lines in the format:

```
modifier + key : command
```

Example:

```
alt + shift + return : komorebic promote
```

### Application-Specific Bindings

Execute different commands based on the focused application:

```
alt + n [
    Firefox       : echo "hello firefox"
    Google Chrome : echo "hello chrome"
    Default       : echo "hello other apps"
]
```

Process names can be found with:

```powershell
Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object ProcessName
```

### Modifier Keys

Available modifiers:

- `alt` - Alt key
- `ctrl` - Ctrl key
- `shift` - Shift key
- `win` - Windows key

Combine with `+`:

```
alt + shift + ctrl + key : command
```

### Key Codes

For special keys, refer to [Virtual Key Codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes).

Remove `VK_` prefix and use lowercase:

- `VK_OEM_PLUS` → `oem_plus` (= key)
- `VK_OEM_MINUS` → `oem_minus` (- key)
- `VK_OEM_4` → `oem_4` ([ key)
- `VK_OEM_6` → `oem_6` (] key)
- `VK_OEM_1` → `oem_1` (; key)

### Shell Selection

At the top of the file:

```
.shell powershell  # or pwsh, or cmd
```

- `powershell` - Built-in PowerShell (Windows 10+)
- `pwsh` - PowerShell 7+ (if installed)
- `cmd` - Command Prompt

## Windows Key Limitations

Windows reserves some Win key combinations (like Win+L to lock). whkd v0.2.4+ can override most limitations, but you may need to modify the registry to disable specific Windows shortcuts:

To disable Win+L lock screen:

```powershell
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableLockWorkstation" -Value 1
```

## Reloading Configuration

After editing `whkdrc`:

**Method 1**: Use the keybinding

```
Alt + Shift + O
```

**Method 2**: Run manually

```powershell
taskkill /f /im whkd.exe
Start-Process whkd -WindowStyle hidden
```

**Method 3**: Restart komorebi (which auto-restarts whkd)

```powershell
komorebic stop
komorebic start --whkd
```

## Testing Keybindings

To test if whkd is capturing keys:

1. Run whkd with output: `whkd`
2. Press keybindings and watch console output
3. Use `Ctrl+C` to stop

## Troubleshooting

### Keybinding Not Working

1. Check whkd is running:

   ```powershell
   Get-Process whkd
   ```

2. Verify syntax in whkdrc (no syntax errors)

3. Check if key combo conflicts with Windows shortcuts

4. Run whkd manually to see error messages:
   ```powershell
   whkd
   ```

### Accidental Key Presses

Use `.pause` directive to toggle all hotkeys:

```
.pause alt + shift + p
```

Then `Alt + Shift + P` will enable/disable all other bindings.

### Special Characters in Commands

Use single quotes for PowerShell strings with special chars:

```
alt + o : Write-Host 'Hello, world!'
```

## Integration with komorebi

All `komorebic` commands in this file control the komorebi window manager. For a complete list of available commands:

```powershell
komorebic --help
```

Or see: https://lgug2z.github.io/komorebi/cli/quickstart.html

## Resources

- [whkd GitHub](https://github.com/LGUG2Z/whkd)
- [whkd README](https://github.com/LGUG2Z/whkd/blob/main/README.md)
- [komorebi CLI Reference](https://lgug2z.github.io/komorebi/cli/quickstart.html)
- [Virtual Key Codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)

## Comparison with macOS (AeroSpace/SKHD)

This configuration maintains ~95% keybinding compatibility with the macOS setup:

| Function            | macOS              | Windows            | Notes     |
| ------------------- | ------------------ | ------------------ | --------- |
| Workspace switching | Cmd + 1-9          | Win + 1-9          | Cmd → Win |
| Window focus        | Alt + HJKL         | Alt + HJKL         | Identical |
| Window movement     | Alt + Shift + HJKL | Alt + Shift + HJKL | Identical |
| Move to workspace   | Alt + Shift + 1-9  | Alt + Shift + 1-9  | Identical |
| Toggle float        | Alt + T            | Alt + T            | Identical |
| Fullscreen          | Alt + F            | Alt + F            | Identical |
| Close window        | Alt + W            | Alt + W            | Identical |

This design allows seamless transition between macOS and Windows environments.
