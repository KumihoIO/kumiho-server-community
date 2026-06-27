#!/usr/bin/env sh
# Register kumiho-server CE to auto-start at login on macOS via a launchd
# LaunchAgent. Runs ../kumiho-ce-up.sh (DBs + server, loopback only).
#
#   ./autostart/install-launchd.sh            # install + load
#   ./autostart/install-launchd.sh --uninstall
set -eu

LABEL="io.kumiho.ce"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOGDIR="$HOME/Library/Logs/kumiho-ce"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UP="$(cd "$SCRIPT_DIR/.." && pwd)/kumiho-ce-up.sh"

if [ "${1:-}" = "--uninstall" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Removed $LABEL. (Docker DBs still running: docker compose -f '$(cd "$SCRIPT_DIR/.." && pwd)/docker-compose.yml' down)"
    exit 0
fi

chmod +x "$UP" 2>/dev/null || true
mkdir -p "$LOGDIR" "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>$UP</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOGDIR/server.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGDIR/server.err.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "Loaded LaunchAgent $LABEL."
echo "  Logs:   $LOGDIR/"
echo "  Stop:   launchctl unload '$PLIST'"
echo "  Remove: ./autostart/install-launchd.sh --uninstall"
echo
echo "Ensure Docker Desktop is set to start at login (Settings > General)."
