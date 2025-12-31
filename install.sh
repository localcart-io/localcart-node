#!/usr/bin/env bash
set -e

# Resolve absolute path of the repo (directory containing this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="$(whoami)"
NODE_BIN="$(command -v node)"

if [ -z "$NODE_BIN" ]; then
  echo "Node.js is not installed or not in PATH"
  exit 1
fi

echo "Installing dependencies in $SCRIPT_DIR"
cd "$SCRIPT_DIR"
npm install

# Create systemd service
SERVICE_FILE="/etc/systemd/system/localcart-node.service"

echo "Creating systemd service at $SERVICE_FILE"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=localcart node
Wants=localcart-startup.service
After=localcart-startup.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$SCRIPT_DIR
EnvironmentFile=/etc/environment
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=$NODE_BIN $SCRIPT_DIR/localcart-node.js
Restart=on-failure
RestartSec=3
StandardOutput=append:/var/log/localcart-node.log
StandardError=append:/var/log/localcart-node.log

[Install]
WantedBy=multi-user.target
EOF

# Reload + enable service
sudo systemctl daemon-reload
sudo systemctl enable localcart-node.service

# Ensure daily reboot cron exists only once
if ! grep -q "root\s\+reboot" /etc/crontab; then
  echo "0 0 * * * root reboot" | sudo tee -a /etc/crontab > /dev/null
fi

echo "Installation complete. Rebooting…"
sudo reboot