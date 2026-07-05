#!/bin/bash
set -e

if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed."
    echo "Install it first: https://www.swift.org/install/linux/"
    exit 1
fi

echo "Found Swift: $(swift --version | head -1)"

REPO_URL="https://github.com/Xocash695/appcurfew-agent.git"
INSTALL_DIR="/opt/appcurfew-agent"

echo "Cloning appcurfew-agent..."
if [ -d "$INSTALL_DIR" ]; then
    echo "Existing install found, pulling latest..."
    sudo git -C "$INSTALL_DIR" pull
else
    sudo git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

echo "Building appcurfew-agent (release mode)..."
sudo swift build -c release

echo "Installing binary to /usr/local/bin..."
sudo cp .build/release/appcurfew-agent /usr/local/bin/appcurfew-agent
sudo chmod +x /usr/local/bin/appcurfew-agent

echo "Installing systemd template unit..."
sudo cp appcurfew-agent@.service /etc/systemd/system/appcurfew-agent@.service
sudo systemctl daemon-reload

sudo mkdir -p /etc/appcurfew

echo ""
echo "This machine may be shared by multiple children, each with their own"
echo "Linux user account. Let's set up (or add) one child's agent now."
echo ""
read -p "Child's Linux username on this machine: " CHILD_USERNAME
read -p "Server URL (e.g. http://100.x.x.x:8080): " SERVER_URL
read -p "This child's API key: " API_KEY

CONFIG_PATH="/etc/appcurfew/${CHILD_USERNAME}.json"
echo "{\"serverURL\": \"$SERVER_URL\", \"apiKey\": \"$API_KEY\", \"childUsername\": \"$CHILD_USERNAME\"}" | sudo tee "$CONFIG_PATH" > /dev/null
echo "Config written to $CONFIG_PATH"

sudo systemctl enable --now "appcurfew-agent@${CHILD_USERNAME}"

echo ""
echo "Done! Check status with: sudo systemctl status appcurfew-agent@${CHILD_USERNAME}"
echo "View live logs with: sudo journalctl -u appcurfew-agent@${CHILD_USERNAME} -f"
echo ""
echo "To add ANOTHER child on this same machine, just run this script again."
