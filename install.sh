#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

PORT="${OPENCLAW_HQ_PORT:-7843}"
OS="$(uname -s)"

echo "=== OpenClaw HQ Installer ==="
echo ""

# ── Python check ──
PY=""
for cmd in python3 python; do
  if command -v "$cmd" &>/dev/null; then
    ver=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    if [ "$major" = "3" ] && [ "$minor" -ge 10 ]; then
      PY="$cmd"
      break
    fi
  fi
done

if [ -z "$PY" ]; then
  echo "ERROR: Python 3.10+ is required but not found."
  echo "Install Python 3.10+ and try again."
  exit 1
fi
echo "Using Python: $PY ($($PY --version 2>&1))"

# ── Venv + deps ──
if [ ! -d ".venv" ]; then
  echo "Creating virtual environment..."
  $PY -m venv .venv
fi

echo "Installing dependencies..."
.venv/bin/pip install -q -r requirements.txt
echo "Dependencies installed."

# ── Service setup ──
echo ""
read -rp "Install as system service? [y/N] " INSTALL_SVC
if [[ "$INSTALL_SVC" =~ ^[Yy]$ ]]; then
  if [ "$OS" = "Darwin" ]; then
    # macOS: launchd plist
    PLIST="$HOME/Library/LaunchAgents/com.openclaw.hq.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.openclaw.hq</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DIR}/.venv/bin/python</string>
    <string>${DIR}/dashboard.py</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${DIR}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OPENCLAW_HQ_PORT</key>
    <string>${PORT}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw-hq.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw-hq.log</string>
</dict>
</plist>
PEOF
    launchctl load "$PLIST" 2>/dev/null || true
    echo "Installed launchd service: com.openclaw.hq"
    echo "  Start:  launchctl load $PLIST"
    echo "  Stop:   launchctl unload $PLIST"

  else
    # Linux: systemd user service
    UNIT_DIR="$HOME/.config/systemd/user"
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT_DIR/openclaw-hq.service" <<SEOF
[Unit]
Description=OpenClaw HQ
After=network.target

[Service]
Type=simple
WorkingDirectory=${DIR}
ExecStart=${DIR}/.venv/bin/python ${DIR}/dashboard.py
Environment=OPENCLAW_HQ_PORT=${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SEOF
    systemctl --user daemon-reload
    systemctl --user enable openclaw-hq.service
    systemctl --user start openclaw-hq.service
    echo "Installed systemd user service: openclaw-hq"
    echo "  Status: systemctl --user status openclaw-hq"
    echo "  Stop:   systemctl --user stop openclaw-hq"
    echo "  Logs:   journalctl --user -u openclaw-hq -f"
  fi
fi

echo ""
echo "=== Installation complete ==="
echo "  Run manually:  ./run.sh"
echo "  Dashboard URL:  http://localhost:${PORT}"
