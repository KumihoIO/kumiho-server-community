#Requires -Version 5.1
<#
.SYNOPSIS
    Register kumiho-server CE to auto-start at logon on Windows via the Task
    Scheduler. The task runs ..\kumiho-ce-up.ps1 (DBs + server, loopback only)
    under your user account, hidden.

.EXAMPLE
    .\autostart\register-task.ps1
.EXAMPLE
    .\autostart\register-task.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$TaskName = "KumihoServerCE",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$Up = Join-Path (Split-Path -Parent $ScriptDir) "kumiho-ce-up.ps1"

if ($Uninstall) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction Stop } catch {}
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed scheduled task '$TaskName'."
    } catch {
        Write-Host "No scheduled task '$TaskName' found."
    }
    Write-Host "Note: the Docker databases are still running. Stop them with:"
    Write-Host "  docker compose -f `"$(Join-Path (Split-Path -Parent $ScriptDir) 'docker-compose.yml')`" down"
    return
}

if (-not (Test-Path $Up)) { throw "Launcher not found: $Up" }

$me      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$psExe   = (Get-Command powershell.exe).Source
$taskArg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Up`""

$action    = New-ScheduledTaskAction -Execute $psExe -Argument $taskArg
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $me
$principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
} catch {
    throw "Register-ScheduledTask failed: $($_.Exception.Message)`nPer-user self-registration usually works unelevated; if group policy blocks it, retry from an elevated PowerShell."
}

Write-Host "Registered scheduled task '$TaskName' (runs kumiho-ce-up.ps1 at logon, hidden)."
Write-Host "  Start now: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Logs:      `$env:LOCALAPPDATA\kumiho-ce\"
Write-Host "  Remove:    .\autostart\register-task.ps1 -Uninstall"
Write-Host ""
Write-Host "Ensure Docker Desktop is set to start when you sign in."
