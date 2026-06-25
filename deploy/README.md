# Run kumiho-server CE locally (Windows · macOS · Linux · WSL2)

This bundle runs Community Edition on one machine:

- **Neo4j + Redis in Docker**, published to `127.0.0.1` only
- the **kumiho-server binary on the host**, bound to `127.0.0.1:9190`

CE is tokenless and loopback-only by design — the binary *forces* a loopback
bind, so it is reachable from **this** machine and **refused from every other
machine**, with no setting that can accidentally expose it. (A containerized
server can't preserve that: Docker rewrites even a localhost connection's source
to the bridge gateway, which CE then rejects — so the server runs on the host.)

## 1. Prerequisites

1. **Install CE and onboard** (writes `~/.kumiho/server.toml` + a launch script
   `~/.kumiho/start-kumiho-server.{sh,ps1}`):
   - macOS / Linux / WSL: `curl -fsSL https://github.com/KumihoIO/kumiho-server-community/releases/latest/download/install.sh | sh`
   - Windows (PowerShell): `irm https://github.com/KumihoIO/kumiho-server-community/releases/latest/download/install.ps1 | iex`

   The wizard asks for your **Neo4j port and password** — remember them.
2. **Docker** — Docker Desktop (Windows/macOS) or Docker Engine (Linux). Enable
   "start at login" so it's up when CE starts.
3. **Configure `.env` to match onboarding:**
   ```sh
   cp .env.example .env
   ```
   - **`KUMIHO_NEO4J_PASSWORD` must exactly match the Neo4j password you typed in
     onboarding** — otherwise the server can't authenticate to Neo4j.
   - If you chose **non-default ports** in onboarding, also set `KUMIHO_NEO4J_PORT`
     / `KUMIHO_REDIS_PORT` to the same values. (Defaults are 7687 / 6379; if you
     accepted them you can leave `.env` ports alone.)

## 2. Run it once (foreground)

| OS | Command |
|----|---------|
| macOS / Linux / WSL2 | `./kumiho-ce-up.sh` |
| Windows | `.\kumiho-ce-up.ps1` |

This waits for Docker, starts Neo4j + Redis, waits for Neo4j to be healthy, then
runs the server. Health: `GET http://127.0.0.1:<server-port>/api/_health`
(default port `9190`, or whatever you chose in onboarding). Ctrl-C stops the
server (the databases keep running under Docker's restart policy).

## 3. Auto-start at login

| OS | Mechanism | Install | Remove |
|----|-----------|---------|--------|
| Linux / WSL2 | systemd user service | `./autostart/install-systemd.sh` | `./autostart/install-systemd.sh --uninstall` |
| macOS | launchd LaunchAgent | `./autostart/install-launchd.sh` | `./autostart/install-launchd.sh --uninstall` |
| Windows | Task Scheduler | `.\autostart\register-task.ps1` | `.\autostart\register-task.ps1 -Uninstall` |

Each registers the per-OS launcher above to run at login. Logs:

- Linux/WSL: `journalctl --user -u kumiho-ce -f`
- macOS: `~/Library/Logs/kumiho-ce/`
- Windows: `%LOCALAPPDATA%\kumiho-ce\`

### WSL2 notes
- Enable systemd once: add to `/etc/wsl.conf` →
  ```ini
  [boot]
  systemd=true
  ```
  then `wsl --shutdown` and reopen.
- **Login-start is the reliable mode on WSL2.** To start *at boot* without an
  interactive login you'd also need `sudo loginctl enable-linger "$USER"` **and**
  in-distro Docker Engine — Docker Desktop's WSL socket only appears after the
  Windows app starts, so it isn't available on a headless boot.
- Docker: use Docker Desktop's WSL integration, or install Docker Engine in the distro.

## Notes

- **Password** is applied on the first Neo4j volume init; changing it later does
  not re-key an existing volume (`docker compose down -v` wipes data and starts
  fresh). It must match `db_pass` in `~/.kumiho/server.toml`.
- **Single-user.** CE caps concurrent connections (compiled-in) so it stays a
  single-user server; extra connections are refused at accept time.
- **No Neo4j plugins** are bundled: CE uses Neo4j's native vector index.
- **Redis is optional.** If you left the Redis port blank in onboarding, event
  streaming is disabled; you may drop the `redis` service from
  `docker-compose.yml` to save resources (leaving it running is harmless).
- **Never expose CE to a network or a proxy.** It is tokenless; the loopback
  checks are isolation, not authentication.
