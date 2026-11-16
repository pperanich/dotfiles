#Requires -RunAsAdministrator
<#
Keep a WSL distro running on this Windows machine with nobody signed in, so the NixOS
guest (pp-wsl1) stays reachable for deploys, backups and the Gitea runner.

  1. The PC never sleeps or hibernates on AC power.
  2. WSL never stops the VM or the distro for being idle (%UserProfile%\.wslconfig).
  3. A scheduled task starts the distro at boot, signed in or not, and restarts it if it exits.

Run once in an elevated PowerShell, as the account that owns the distro:
  powershell -ExecutionPolicy Bypass -File .\wsl-keepalive.ps1 [-Distro NixOS]
Check afterwards by rebooting, not signing in, and from pp-ml1: tailscale ping pp-wsl1
#>
param(
  [string]$Distro = ""
)
$ErrorActionPreference = "Stop"

if (-not $Distro) {
  $distros = @(wsl.exe --list --quiet | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
  if ($distros.Count -ne 1) {
    throw "Found $($distros.Count) distros ($($distros -join ', ')); pass -Distro <name>."
  }
  $Distro = $distros[0]
}
Write-Host "Distro: $Distro"

# 1. No sleep or hibernation on AC (a sleeping PC takes the distro and its tailnet node down).
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# 2. Idle timeouts, merged into any existing .wslconfig without touching other keys.
function Set-IniValue([string[]]$Lines, [string]$Section, [string]$Key, [string]$Value) {
  $out = [System.Collections.Generic.List[string]]::new()
  $inSection = $false; $done = $false; $sawSection = $false
  foreach ($line in $Lines) {
    if ($line -match '^\s*\[(.+)\]\s*$') {
      if ($inSection -and -not $done) { $out.Add("$Key=$Value"); $done = $true }
      $inSection = ($Matches[1] -eq $Section)
      if ($inSection) { $sawSection = $true }
    } elseif ($inSection -and $line -match "^\s*$([regex]::Escape($Key))\s*=") {
      $out.Add("$Key=$Value"); $done = $true; continue
    }
    $out.Add($line)
  }
  if (-not $done) {
    if (-not $sawSection) { $out.Add("[$Section]") }
    $out.Add("$Key=$Value")
  }
  return $out.ToArray()
}
$cfg = Join-Path $env:USERPROFILE ".wslconfig"
$lines = if (Test-Path $cfg) { Get-Content $cfg } else { @() }
$lines = Set-IniValue $lines "wsl2" "vmIdleTimeout" "-1"
$lines = Set-IniValue $lines "general" "instanceIdleTimeout" "-1"
Set-Content -Path $cfg -Value $lines -Encoding ascii
Write-Host "Updated $cfg"

# 3. Start the distro at boot without a sign-in (S4U: runs whether or not you are signed in,
#    stores no password) and keep one process in it so it never counts as idle.
$taskName = "WSL keep-alive ($Distro)"
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $Distro --exec /bin/sh -c `"exec sleep infinity`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "Registered scheduled task '$taskName'"

# Apply the new .wslconfig now, then start the task.
wsl.exe --shutdown
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 10
wsl.exe --list --running
