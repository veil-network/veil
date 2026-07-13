#!/bin/bash
set -e

echo "=== Veil Server Installer v1.3.1 ==="
echo ""

# Check OS
if [ "$(uname -s)" != "Linux" ]; then
    echo "Error: This script requires Linux"
    exit 1
fi

# Check root
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Download veil-server
echo "[1/7] Downloading veil-server..."
curl -fsSL -o /usr/local/bin/veil-server https://github.com/veil-network/veil/releases/latest/download/veil-server
chmod +x /usr/local/bin/veil-server

# Download GME model
echo "[2/7] Downloading GME model..."
mkdir -p /usr/local/share/veil/models
curl -fsSL -o /usr/local/share/veil/models/behavior_news.json https://github.com/veil-network/veil/releases/latest/download/behavior_news.json

# Generate PSK
echo "[3/7] Generating PSK..."
PSK=$(openssl rand -base64 32)
echo "Your PSK (save this!): $PSK"
echo ""

# Create systemd service
echo "[4/7] Creating systemd service..."
cat > /etc/systemd/system/veil-server.service << EOF
[Unit]
Description=Veil Server
After=network.target

[Service]
Type=simple
User=root
Environment=VEIL_PSK=$PSK
ExecStart=/usr/local/bin/veil-server --mode server --listen :443 --gme-model /usr/local/share/veil/models/behavior_news.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Optional: TTL=128
echo "[5/7] Configuring network..."
iptables -t mangle -A OUTPUT -p tcp --sport 443 -j TTL --ttl-set 128 2>/dev/null || echo "  TTL setting skipped (iptables not available)"

# Optional: TCP Fast Open
sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || echo "  TFO setting skipped"

# Start server
echo "[6/7] Starting server..."
systemctl daemon-reload
systemctl enable veil-server
systemctl start veil-server

# Show status
echo "[7/7] Checking status..."
sleep 2
systemctl status veil-server --no-pager

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Your PSK: $PSK"
echo ""
echo "Save this PSK! You will need it to connect."
echo ""
echo "Next steps:"
echo "1. Download veil.exe (Windows) or veil.apk (Android) from:"
echo "   https://github.com/veil-network/veil/releases/latest"
echo "2. Run: veil.exe --mode client --listen :1080 --target $(curl -s ifconfig.me):443"
echo "3. Set SOCKS5 proxy in your browser to 127.0.0.1:1080"
echo ""
echo "Server logs: journalctl -u veil-server -f"