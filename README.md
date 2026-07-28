# Veil v1.3.1 — User Guide

## What is Veil

Veil is a SOCKS5 proxy that makes your traffic look like regular Chrome browsing. It hides the fact that you're using a proxy at all. Your ISP sees HTTPS traffic to your VPS that looks identical to someone browsing YouTube or Google.

## How it works

Your traffic is wrapped in TLS 1.3, padded with structured noise, and multiplexed through HTTP/2 streams that mimic Chrome browser behavior.

## Quick Start

### 1. Get a VPS

Rent a Linux VPS (Ubuntu 24.04 recommended) with a public IP address, TCP port 443 open, and at least 512 MB RAM.

### 2. Deploy the server

Run this command on your VPS:

curl -fsSL https://raw.githubusercontent.com/veil-network/veil/main/install.sh | sh

The script will download the server binary, generate a PSK (secret key), create SSL certificate, configure and start the server, and show your PSK — save it.

### 3. Run the client (Windows)

set VEIL_PSK=<YOUR_PSK>
veil.exe --mode client --listen :1080 --target <VPS_IP>:443

Keep the console window open. Close it to stop the proxy.

### 4. Configure your browser

Set SOCKS5 proxy to 127.0.0.1:1080. In Firefox: Settings → Network Settings → Manual proxy configuration → SOCKS Host: 127.0.0.1, Port: 1080 → SOCKS v5. In Chrome: use an extension like SwitchyOmega or start with --proxy-server="socks5://127.0.0.1:1080".

### 5. Verify

Open https://2ip.ru in your browser. It should show your VPS IP address.

## Android

Install veil.apk on your device. Open the app, enter your VPS address and PSK, tap Connect. Configure your browser to use SOCKS5 proxy 127.0.0.1:1080. The app runs as a foreground service with a persistent notification. It survives app switching and screen lock.

## Command Line Options

--mode client|server (default: client)
--listen :1080 SOCKS5 listen address
--target VPS:443 VPS address (host:port)
--duress-code "" Duress code for silent alarm
--cert-fingerprint "" Server certificate SHA256
--session-resumption true Enable TLS session resumption
--log-level info info or debug

## Duress Mode

If you are forced to reveal your proxy usage, use the duress code: veil.exe --mode client --listen :1080 --target <VPS_IP>:443 --duress-code "your-secret-code". The server will show a fake login page instead of proxying traffic. Your real PSK continues to work normally. Set VEIL_DURESS_PSK on the server for additional protection.

## Certificate Pinning

Get certificate fingerprint: openssl s_client -connect <VPS_IP>:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha256. Then use it: veil.exe --cert-fingerprint "AA:BB:CC:..." ...

## Security Notes

Store your PSK securely. Never share it. Use certificate pinning if possible. The duress PSK should be different from your real PSK. The client binary is obfuscated.

## Troubleshooting

Connection refused: check if server is running (systemctl status veil-server) and port 443 is open. Certificate error: use --cert-fingerprint or disable pinning. Pages don't load: check server logs (journalctl -u veil-server -f), verify PSK matches on client and server, check system time (timedatectl status). Slow browsing: this is expected for the first release. Multiple heavy sites simultaneously may cause slowdowns.

## License

MIT License.

## Disclaimer

Veil is a research project for educational purposes. Users are responsible for compliance with local regulations. The authors assume no liability for misuse.Veil v1.3.1 — User Guide
What is Veil

Veil is a SOCKS5 proxy that makes your traffic look like regular Chrome browsing. It hides the fact that you're using a proxy at all. Your ISP sees HTTPS traffic to your VPS that looks identical to someone browsing YouTube or Google.
How it works
text

You → Veil Client → VPS (your server) → Internet

Your traffic is wrapped in TLS 1.3, padded with structured noise, and multiplexed through HTTP/2 streams that mimic Chrome browser behavior.
Quick Start
1. Get a VPS

Rent a Linux VPS (Ubuntu 24.04 recommended) with:

    Public IP address

    TCP port 443 open

    At least 512 MB RAM

2. Deploy the server

Run this command on your VPS:
bash

curl -fsSL https://raw.githubusercontent.com/veil-network/veil/main/install.sh | sh

The script will:

    Download the server binary

    Generate a PSK (secret key)

    Create SSL certificate

    Configure and start the server

    Show your PSK — save it!

3. Run the client (Windows)
powershell

set VEIL_PSK=<YOUR_PSK>
veil.exe --mode client --listen :1080 --target <VPS_IP>:443

Keep the console window open. Close it to stop the proxy.
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

    Store your PSK securely. Never share it.

    Use certificate pinning if possible.

    The duress PSK should be different from your real PSK.

    The client binary is obfuscated.

Troubleshooting

Connection refused:

    Is the server running? systemctl status veil-server

    Is port 443 open? Check firewall

Certificate error:

    Use --cert-fingerprint or disable pinning

Pages don't load:

    Check server logs: journalctl -u veil-server -f

    Verify PSK matches on client and server

    Check system time: timedatectl status

Slow browsing:

    This is expected for the first release

    Multiple heavy sites simultaneously may cause slowdowns

License

MIT License.
Disclaimer

Veil is a research project for educational purposes. Users are responsible for compliance with local regulations. The authors assume no liability for misuse.
