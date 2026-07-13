Veil v1.3.1 — User Guide
What is Veil
Veil is a SOCKS5 proxy that makes your traffic look like regular Chrome browsing. It hides the fact that you're using a proxy at all. Your ISP sees HTTPS traffic to your VPS that looks identical to someone browsing YouTube or Google.
How it works
text
You → Veil Client → VPS (your server) → Internet
Your traffic is wrapped in TLS 1.3, padded with structured noise, and multiplexed through HTTP/2 streams that mimic Chrome browser behavior.
Quick Start
1. Get a VPS
Rent a Linux VPS (Ubuntu 24.04 recommended) with:
•	Public IP address
•	TCP port 443 open
•	At least 512 MB RAM
2. Deploy the server
bash
# Copy veil-server to your VPS
scp veil-server root@<VPS_IP>:/root/

# SSH to your VPS
ssh root@<VPS_IP>

# Generate PSK
openssl rand -base64 32
# Save the output - this is your secret key

# Create systemd service
cat > /etc/systemd/system/veil-server.service << 'EOF'
[Unit]
Description=Veil Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment=VEIL_PSK=<YOUR_PSK>
ExecStart=/root/veil-server --mode server --listen :443
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Optional: Set Windows TTL
iptables -t mangle -A OUTPUT -p tcp --sport 443 -j TTL --ttl-set 128

# Optional: Enable TCP Fast Open
sysctl -w net.ipv4.tcp_fastopen=3

# Start the server
systemctl daemon-reload
systemctl enable veil-server
systemctl start veil-server
systemctl status veil-server
3. Run the client (Windows)
Command line:
powershell
set VEIL_PSK=<YOUR_PSK>
veil.exe --mode client --listen :1080 --target <VPS_IP>:443
GUI (system tray):
powershell
veil.exe --tray
Right-click the tray icon → Settings → enter VPS address and PSK → Connect.
4. Configure your browser
Set SOCKS5 proxy to 127.0.0.1:1080.
Firefox: Settings → Network Settings → Manual proxy configuration → SOCKS Host: 127.0.0.1, Port: 1080 → SOCKS v5.
Chrome: Use an extension like SwitchyOmega or start with --proxy-server="socks5://127.0.0.1:1080".
5. Verify
Open https://2ip.ru in your browser. It should show your VPS IP address.
Android
Install veil.apk on your device. Open the app, enter your VPS address and PSK, tap Connect. Configure your browser to use SOCKS5 proxy 127.0.0.1:1080.
The app runs as a foreground service with a persistent notification. It survives app switching and screen lock.
Command Line Options
Flag	Default	Description
--mode	client	client or server
--listen	:1080	SOCKS5 listen address
--target	—	VPS address (host:port)
--duress-code	""	Duress code for silent alarm
--cert-fingerprint	""	Server certificate SHA256
--session-resumption	true	Enable TLS session resumption
--log-level	info	info or debug
--tray	—	Launch GUI with system tray
Duress Mode
If you are forced to reveal your proxy usage, use the duress code:
powershell
veil.exe --mode client --listen :1080 --target <VPS_IP>:443 --duress-code "your-secret-code"
The server will show a fake login page instead of proxying traffic. Your real PSK continues to work normally.
Set VEIL_DURESS_PSK on the server for additional protection.
Certificate Pinning
To protect against MITM attacks, pin your server certificate:
powershell
# Get certificate fingerprint
openssl s_client -connect <VPS_IP>:443 </dev/null 2>/dev/null | openssl x509 -fingerprint -sha256

# Use it
veil.exe --cert-fingerprint "AA:BB:CC:..." ...
Security Notes
•	Store your PSK securely. Never share it.
•	Use certificate pinning if possible.
•	The duress PSK should be different from your real PSK.
•	Default PSK is for testing only. Change it.
•	The client binary is obfuscated.
Troubleshooting
Connection refused:
•	Is the server running? systemctl status veil-server
•	Is port 443 open? Check firewall
Certificate error:
•	Use --cert-fingerprint or disable pinning
Pages don't load:
•	Check server logs: journalctl -u veil-server -f
•	Verify PSK matches on client and server
•	Check system time: timedatectl status
Slow browsing:
•	This is expected for the first release
•	Multiple heavy sites simultaneously may cause slowdowns
License
MIT License.
Disclaimer
Veil is a research project for educational purposes. Users are responsible for compliance with local regulations. The authors assume no liability for misuse.

