# ================================================================
# Windows Window Manager Installation Script
# Installs komorebi and whkd on Windows
# ================================================================

# Set strict error handling
$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------
# Logging Functions
# ----------------------------------------------------------------

function Write-InfoLog {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-WarnLog {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# ----------------------------------------------------------------
# System Detection Functions
# ----------------------------------------------------------------

function Test-IsWSL {
    return ($null -ne $env:WSL_DISTRO_NAME) -or ($null -ne $env:WSL_INTEROP)
}

function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    return [version]$os.Version
}

# ----------------------------------------------------------------
# Installation Functions
# ----------------------------------------------------------------

function Enable-LongPaths {
    Write-InfoLog "Enabling long path support..."

    if (-not (Test-IsAdmin)) {
        Write-WarnLog "Admin privileges required to enable long paths. Skipping..."
        return
    }

    try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
        Write-InfoLog "Long path support enabled successfully"
    }
    catch {
        Write-WarnLog "Failed to enable long path support: $_"
    }
}

function Test-WingetAvailable {
    try {
        $null = winget --version
        return $true
    }
    catch {
        return $false
    }
}

function Install-WingetIfMissing {
    if (Test-WingetAvailable) {
        Write-InfoLog "Winget is already installed"
        return $true
    }

    Write-WarnLog "Winget is not installed"
    Write-InfoLog "Please install winget from the Microsoft Store or visit:"
    Write-InfoLog "https://learn.microsoft.com/en-us/windows/package-manager/winget/"
    return $false
}

function Install-WindowsWM {
    Write-InfoLog "Installing komorebi, whkd, komorebi-bar, and Alacritty..."

    try {
        # Install komorebi (includes komorebi-bar)
        Write-InfoLog "Installing komorebi..."
        winget install --id LGUG2Z.komorebi --silent --accept-source-agreements --accept-package-agreements

        # Install whkd
        Write-InfoLog "Installing whkd..."
        winget install --id LGUG2Z.whkd --silent --accept-source-agreements --accept-package-agreements

        # Install Alacritty
        Write-InfoLog "Installing Alacritty..."
        winget install --id Alacritty.Alacritty --silent --accept-source-agreements --accept-package-agreements

        Write-InfoLog "komorebi, whkd, komorebi-bar, and Alacritty installed successfully"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to install packages: $_"
        return $false
    }
}

function New-ConfigDirectories {
    Write-InfoLog "Creating configuration directories..."

    $dirs = @(
        "$env:USERPROFILE\.config",
        "$env:USERPROFILE\.config\komorebi",
        "$env:USERPROFILE\.config\whkd",
        "$env:USERPROFILE\.config\alacritty"
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-InfoLog "Created directory: $dir"
        }
    }
}

function Deploy-Configs {
    Write-InfoLog "Deploying configuration files..."

    # Determine dotfiles path
    $scriptPath = Split-Path -Parent $PSCommandPath
    $dotfilesPath = Split-Path -Parent $scriptPath

    # Config source paths
    $komorebiFCfg = Join-Path $dotfilesPath "home\.config\komorebi\komorebi.json"
    $komorebiBarCfg = Join-Path $dotfilesPath "home\.config\komorebi\komorebi.bar.json"
    $whkdCfg = Join-Path $dotfilesPath "home\.config\whkd\whkdrc"
    $alacrittyCfg = Join-Path $dotfilesPath "home\.config\alacritty\alacritty.toml"

    # Config destination paths
    $komorebiDest = "$env:USERPROFILE\.config\komorebi\komorebi.json"
    $komorebiBarDest = "$env:USERPROFILE\.config\komorebi\komorebi.bar.json"
    $whkdDest = "$env:USERPROFILE\.config\whkd\whkdrc"
    $alacrittyDest = "$env:USERPROFILE\.config\alacritty\alacritty.toml"

    # Check if source files exist
    if (-not (Test-Path $komorebiFCfg)) {
        Write-ErrorLog "komorebi config not found at: $komorebiFCfg"
        return $false
    }
    if (-not (Test-Path $komorebiBarCfg)) {
        Write-ErrorLog "komorebi-bar config not found at: $komorebiBarCfg"
        return $false
    }
    if (-not (Test-Path $whkdCfg)) {
        Write-ErrorLog "whkd config not found at: $whkdCfg"
        return $false
    }
    if (-not (Test-Path $alacrittyCfg)) {
        Write-ErrorLog "Alacritty config not found at: $alacrittyCfg"
        return $false
    }

    try {
        # Try to create symlinks if admin, otherwise copy
        if (Test-IsAdmin) {
            Write-InfoLog "Creating symbolic links (admin mode)..."

            # Remove existing files/links
            if (Test-Path $komorebiDest) { Remove-Item $komorebiDest -Force }
            if (Test-Path $komorebiBarDest) { Remove-Item $komorebiBarDest -Force }
            if (Test-Path $whkdDest) { Remove-Item $whkdDest -Force }
            if (Test-Path $alacrittyDest) { Remove-Item $alacrittyDest -Force }

            # Create symlinks
            New-Item -ItemType SymbolicLink -Path $komorebiDest -Target $komorebiFCfg -Force | Out-Null
            New-Item -ItemType SymbolicLink -Path $komorebiBarDest -Target $komorebiBarCfg -Force | Out-Null
            New-Item -ItemType SymbolicLink -Path $whkdDest -Target $whkdCfg -Force | Out-Null
            New-Item -ItemType SymbolicLink -Path $alacrittyDest -Target $alacrittyCfg -Force | Out-Null

            Write-InfoLog "Configuration symlinks created successfully"
        }
        else {
            Write-WarnLog "Not running as admin, copying files instead of creating symlinks..."

            Copy-Item -Path $komorebiFCfg -Destination $komorebiDest -Force
            Copy-Item -Path $komorebiBarCfg -Destination $komorebiBarDest -Force
            Copy-Item -Path $whkdCfg -Destination $whkdDest -Force
            Copy-Item -Path $alacrittyCfg -Destination $alacrittyDest -Force

            Write-InfoLog "Configuration files copied successfully"
            Write-WarnLog "Note: Changes to dotfiles won't auto-sync. Re-run this script or run as admin for symlinks."
        }

        return $true
    }
    catch {
        Write-ErrorLog "Failed to deploy configs: $_"
        return $false
    }
}

function Enable-Autostart {
    Write-InfoLog "Setting up autostart for komorebi..."

    try {
        # Enable komorebi autostart
        komorebic enable-autostart
        Write-InfoLog "Autostart enabled for komorebi"
        return $true
    }
    catch {
        Write-WarnLog "Failed to enable autostart: $_"
        Write-WarnLog "You can manually enable it later with: komorebic enable-autostart"
        return $false
    }
}

function Get-ApplicationConfig {
    Write-InfoLog "Downloading application-specific configuration..."

    try {
        $output = komorebic fetch-asc 2>&1
        Write-InfoLog "Application-specific configuration downloaded"
        Write-InfoLog "Output: $output"
        return $true
    }
    catch {
        Write-WarnLog "Failed to download application-specific config: $_"
        Write-WarnLog "You can manually download it later with: komorebic fetch-asc"
        return $false
    }
}

function Test-Installation {
    Write-InfoLog "Verifying installation..."

    $commands = @("komorebi", "komorebic", "whkd", "alacritty")
    $allFound = $true

    foreach ($cmd in $commands) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            Write-InfoLog "[OK] $cmd is available"
        }
        catch {
            Write-ErrorLog "[FAIL] $cmd not found in PATH"
            $allFound = $false
        }
    }

    return $allFound
}

# ----------------------------------------------------------------
# Main Installation Flow
# ----------------------------------------------------------------

function Main {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  komorebi + whkd + Alacritty Installation for Windows" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Check if running in WSL
    if (Test-IsWSL) {
        Write-ErrorLog "This script must be run on native Windows, not WSL"
        Write-ErrorLog "komorebi requires native Windows to manage windows"
        exit 1
    }

    # Check Windows version
    $winVersion = Get-WindowsVersion
    $minVersion = [version]"10.0.17763"  # Windows 10 1809
    if ($winVersion -lt $minVersion) {
        Write-ErrorLog "Windows 10 version 1809 or later is required"
        Write-ErrorLog "Current version: $winVersion"
        exit 1
    }

    Write-InfoLog "Windows version: $winVersion [OK]"

    # Check admin status
    if (Test-IsAdmin) {
        Write-InfoLog "Running with administrator privileges [OK]"
    }
    else {
        Write-WarnLog "Not running as administrator"
        Write-WarnLog "Some features (long paths, symlinks) may not be available"
    }

    # Enable long path support
    Enable-LongPaths

    # Check for winget
    if (-not (Install-WingetIfMissing)) {
        Write-ErrorLog "Winget is required but not installed. Please install it first."
        exit 1
    }

    # Install komorebi and whkd
    if (-not (Install-WindowsWM)) {
        Write-ErrorLog "Installation failed"
        exit 1
    }

    # Create config directories
    New-ConfigDirectories

    # Deploy configurations
    if (-not (Deploy-Configs)) {
        Write-ErrorLog "Failed to deploy configuration files"
        exit 1
    }

    # Download application-specific configuration
    Get-ApplicationConfig

    # Enable autostart
    Enable-Autostart

    # Verify installation
    if (-not (Test-Installation)) {
        Write-WarnLog "Some components may not be properly installed"
        Write-WarnLog "You may need to restart your terminal or add programs to PATH"
    }

    # Success message
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-InfoLog "Configuration files deployed to: $env:USERPROFILE\.config"
    Write-Host ""
    Write-InfoLog "Next steps:"
    Write-Host "  1. Restart your terminal (or source your profile)" -ForegroundColor Cyan
    Write-Host "  2. Launch Alacritty terminal (with Catppuccin Mocha theme)" -ForegroundColor Cyan
    Write-Host "  3. Start komorebi with status bar: komorebic start --whkd --bar" -ForegroundColor Cyan
    Write-Host "     Or without status bar: komorebic start --whkd" -ForegroundColor Cyan
    Write-Host "  4. Test keybindings (see ~/.config/whkd/whkdrc)" -ForegroundColor Cyan
    Write-Host "  5. Customize configs in: $env:USERPROFILE\.config\" -ForegroundColor Cyan
    Write-Host ""
    Write-InfoLog "Keybinding highlights:"
    Write-Host "  - Win + 1-9/0        : Switch workspace" -ForegroundColor Cyan
    Write-Host "  - Alt + H/J/K/L      : Focus window" -ForegroundColor Cyan
    Write-Host "  - Alt + Shift + H/J/K/L : Move window" -ForegroundColor Cyan
    Write-Host "  - Alt + Shift + 1-9  : Move window to workspace" -ForegroundColor Cyan
    Write-Host "  - Alt + T            : Toggle float" -ForegroundColor Cyan
    Write-Host "  - Alt + F            : Toggle fullscreen" -ForegroundColor Cyan
    Write-Host "  - Alt + W            : Close window" -ForegroundColor Cyan
    Write-Host "  - Alt + Shift + O    : Reload whkd config" -ForegroundColor Cyan
    Write-Host "  - Alt + Shift + R    : Reload komorebi config" -ForegroundColor Cyan
    Write-Host ""
    Write-InfoLog "For more information, visit:"
    Write-Host "  - https://lgug2z.github.io/komorebi/" -ForegroundColor Cyan
    Write-Host "  - https://github.com/LGUG2Z/whkd" -ForegroundColor Cyan
    Write-Host "  - https://alacritty.org/" -ForegroundColor Cyan
    Write-Host ""
}

# Run main installation
try {
    Main
    exit 0
}
catch {
    Write-ErrorLog "Installation failed with error: $_"
    Write-ErrorLog $_.ScriptStackTrace
    exit 1
}
