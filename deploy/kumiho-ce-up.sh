#!/usr/bin/env sh
# Bring up kumiho-server Community Edition on macOS / Linux / WSL2:
#   1. wait for the Docker engine
#   2. start Neo4j + Redis (published to 127.0.0.1 only)
#   3. wait for Neo4j to be healthy
#   4. run the server via the onboard-generated launch script (loopback only)
#
# Usable directly (foreground) or as the ExecStart of the systemd/launchd unit
# installed by ./autostart/. Prerequisite: run `kumiho_server onboard` first so
# ~/.kumiho/start-kumiho-server.sh exists, and copy .env.example -> .env with the
# Neo4j password (and any non-default ports) matching what you entered there.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
KUMIHO_HOME="${KUMIHO_HOME:-$HOME/.kumiho}"
LAUNCH="$KUMIHO_HOME/start-kumiho-server.sh"

# systemd/launchd run with a minimal PATH and do NOT source your shell profile,
# so make the Docker CLI reachable across the common install locations
# (Homebrew, Docker Desktop "user" install at ~/.docker/bin, the app bundle).
PATH="$PATH:/usr/local/bin:/opt/homebrew/bin:$HOME/.docker/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin"
export PATH

log() { printf '%s  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1"; }

command -v docker >/dev/null 2>&1 || {
    log "docker CLI not found on PATH. Is Docker installed/running? PATH=$PATH"
    exit 1
}

# Docker Compose v2 (`docker compose`) with a fallback to v1 (`docker-compose`).
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    log "Neither 'docker compose' nor 'docker-compose' is available."; exit 1
fi

# Resolve .env from THIS directory (not the cwd) so the password/ports reach
# compose under systemd/launchd and under Compose v1 (which reads .env from cwd).
dc() {
    if [ -f "$ENV_FILE" ]; then
        $COMPOSE_CMD --env-file "$ENV_FILE" -f "$COMPOSE" "$@"
    else
        $COMPOSE_CMD -f "$COMPOSE" "$@"
    fi
}

# 1. Wait for the Docker engine (up to ~5 min).
i=0
until docker info >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then log "Docker engine not ready; aborting."; exit 1; fi
    sleep 5
done

# 2. Start the databases.
log "Starting Neo4j + Redis..."
dc up -d

# 3. Wait for Neo4j health (up to ~2 min).
i=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' kumiho-ce-neo4j 2>/dev/null)" = "healthy" ]; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then log "Neo4j did not become healthy; aborting."; exit 1; fi
    sleep 2
done
log "Neo4j healthy."

# 4. Run the server via the onboard launch script (sets KUMIHO_CONFIG, execs the
#    binary, binds 127.0.0.1 only).
if [ ! -f "$LAUNCH" ]; then
    log "Launch script not found: $LAUNCH"
    log "Run 'kumiho_server onboard' first to generate it."
    exit 1
fi
log "Starting kumiho-server CE on 127.0.0.1 (loopback only)..."
exec sh "$LAUNCH"
