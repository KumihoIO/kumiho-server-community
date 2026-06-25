#!/usr/bin/env sh
# Register kumiho-server CE to auto-start at login on Linux / WSL2 via a systemd
# USER service. Runs ../kumiho-ce-up.sh (DBs + server, loopback only).
#
#   ./autostart/install-systemd.sh            # install + start
#   ./autostart/install-systemd.sh --uninstall
set -eu

UNIT="kumiho-ce.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UP="$(cd "$SCRIPT_DIR/.." && pwd)/kumiho-ce-up.sh"

if [ "${1:-}" = "--uninstall" ]; then
    systemctl --user disable --now "$UNIT" 2>/dev/null || true
    rm -f "$UNIT_DIR/$UNIT"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Removed $UNIT. (Docker DBs still running: docker compose -f '$(cd "$SCRIPT_DIR/.." && pwd)/docker-compose.yml' down)"
    exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' \
        "systemd (systemctl) not found." \
        "On WSL2, enable it: add to /etc/wsl.conf:" \
        "  [boot]" \
        "  systemd=true" \
        "then run 'wsl --shutdown' and reopen the distro." >&2
    exit 1
fi

chmod +x "$UP" 2>/dev/null || true
mkdir -p "$UNIT_DIR"
cat > "$UNIT_DIR/$UNIT" <<EOF
[Unit]
Description=kumiho-server Community Edition (Neo4j + Redis + server, loopback only)

[Service]
Type=simple
ExecStart=/bin/sh "$UP"
Restart=always
RestartSec=10
# The launcher waits for Docker/Neo4j, which can take a while at boot.
TimeoutStartSec=600

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$UNIT"

echo "Enabled user service $UNIT."
echo "  Status: systemctl --user status kumiho-ce"
echo "  Logs:   journalctl --user -u kumiho-ce -f"
echo "  Stop:   systemctl --user stop kumiho-ce"
echo "  Remove: ./autostart/install-systemd.sh --uninstall"
echo
echo "To start at BOOT (before you log in), enable lingering once:"
echo "  sudo loginctl enable-linger \"$USER\""
echo "Boot-start needs Docker available headlessly: use Docker Engine in the"
echo "distro ('sudo systemctl enable docker'). On WSL2, Docker Desktop's socket"
echo "only appears after the Windows app starts, so prefer login-start there."
