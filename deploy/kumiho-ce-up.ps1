#Requires -Version 5.1
<#
.SYNOPSIS
    Bring up kumiho-server Community Edition on Windows:
      1. wait for the Docker engine
      2. start Neo4j + Redis (published to 127.0.0.1 only)
      3. wait for Neo4j to be healthy
      4. run the server via the onboard-generated launch script (loopback only)

    Usable directly (foreground) or as the action of the scheduled task
    installed by .\autostart\register-task.ps1. Prerequisite: run
    `kumiho_server onboard` first so ~\.kumiho\start-kumiho-server.ps1 exists,
    and copy .env.example -> .env with the Neo4j password (and any non-default
    ports) matching what you entered there.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir  = $PSScriptRoot
$Compose    = Join-Path $ScriptDir "docker-compose.yml"
$EnvFile    = Join-Path $ScriptDir ".env"
$KumihoHome = if ($env:KUMIHO_HOME) { $env:KUMIHO_HOME } else { Join-Path $env:USERPROFILE ".kumiho" }
$Launch     = Join-Path $KumihoHome "start-kumiho-server.ps1"
$LogDir     = Join-Path $env:LOCALAPPDATA "kumiho-ce"

function Log([string]$m) { Write-Host "$(Get-Date -Format s)  $m" }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker CLI not found. Is Docker Desktop installed and running?"
}

# Pick Compose v2 (docker compose) or fall back to v1 (docker-compose).
docker compose version *> $null
$ComposeV2 = ($LASTEXITCODE -eq 0)

# Resolve .env from THIS directory (deterministic regardless of cwd / Compose version).
$EnvArgs = @()
if (Test-Path $EnvFile) { $EnvArgs = @("--env-file", $EnvFile) }

# 1. Wait for the Docker engine (up to ~5 min).
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    docker info *> $null 2>&1
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $ready) { throw "Docker engine not ready; aborting." }

# 2. Start the databases.
Log "Starting Neo4j + Redis..."
if ($ComposeV2) { & docker compose @EnvArgs -f $Compose up -d }
else            { & docker-compose @EnvArgs -f $Compose up -d }
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed ($LASTEXITCODE)" }

# 3. Wait for Neo4j health (up to ~2 min).
$state = ""
for ($i = 0; $i -lt 60; $i++) {
    $state = docker inspect -f '{{.State.Health.Status}}' kumiho-ce-neo4j 2>$null
    if ($state -eq "healthy") { break }
    Start-Sleep -Seconds 2
}
if ($state -ne "healthy") { throw "Neo4j did not become healthy (last: '$state')" }
Log "Neo4j healthy."

# 4. Run the server via the onboard launch script. Output is captured to log
#    files so the (hidden) scheduled task is observable.
if (-not (Test-Path $Launch)) {
    throw "Launch script not found: $Launch. Run 'kumiho_server onboard' first."
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Log "Starting kumiho-server CE on 127.0.0.1 (loopback only). Logs: $LogDir"

$proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Launch) `
    -NoNewWindow -PassThru -Wait `
    -RedirectStandardOutput (Join-Path $LogDir "server.out.log") `
    -RedirectStandardError  (Join-Path $LogDir "server.err.log")
exit $proc.ExitCode
