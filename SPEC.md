Veil Protocol Specification v1.3.1
Date: 13.07.2026
Version: 1.3.1 (stable)
Purpose: Technical specification for researchers and auditors.
________________________________________
Table of Contents
1.	Project Overview
2.	Operating Environment
3.	System Architecture
4.	Connection Protocol
5.	Cryptographic Architecture
6.	Generative Mimicry Engine
7.	Security Metrics
8.	Known Limitations
9.	Client Applications
________________________________________
1. Project Overview
Veil is a research project in generative network traffic mimicry. It creates synthetic traffic that is statistically indistinguishable from a real Chrome browser on Windows.
Core Paradigm
Veil simulates a Windows + Chrome user at all network levels:
•	TCP/IP: Windows TCP fingerprint (TTL=128, WindowScale=8, MSS=1460, SACK, Timestamp)
•	TLS 1.3: Chrome-compatible cipher suites and extensions (JA3: Go/Chrome-like)
•	HTTP/2: Variable SETTINGS, PRIORITY frames, WINDOW_UPDATE, PING keep-alive
•	Behavior: Unique session generated per connection — scrolling, video, background updates
Research Applications
•	Testing network analysis systems with realistic traffic
•	Studying HTTP/2 and TLS 1.3 protocol behavior
•	Load testing web servers with browser-like traffic patterns
•	Educational purposes: network protocol research
________________________________________
2. Operating Environment
The protocol is designed for networks with active traffic analysis. Current measures include:
•	Allowlist filtering for mobile networks
•	Behavioral traffic scoring
•	SNI-based filtering
•	Protocol signature detection
Design Decisions
•	VPS with clean IP address
•	Domain legend resolving to VPS IP
•	TCP 443 only
•	No CloudFlare proxying
•	ECH support pending Go standard library (Go 1.28+)
________________________________________
3. System Architecture
3.1. Client
text
Applications → SOCKS5 (:1080)
→ ConnectionManager (connection pool, lifecycle management)
→ Veil Client (crypto/tls, Chrome-compatible parameters)
→ TLS 1.3 handshake
→ MARKER verification
→ PSK authentication (HKDF + ExportKeyingMaterial)
→ HTTP/2 session with FGN padding
→ VPS:443
ConnectionManager (R14):
•	Pool of TCP connections to VPS
•	Lifecycle: Active → Draining → Closed
•	Event-driven model (VCEvent)
•	Half-close stream semantics
•	Idle timeout 120 seconds
•	Concurrent connection creation semaphore (max 4)
3.2. Server
text
VPS:443 → Rate limiter (128 connections)
→ Unified handler (facade + Veil indistinguishable)
→ TLS (crypto/tls)
→ MARKER verification (const-time, ±60s window)
→ PSK authentication (HKDF + duress support)
→ Target address validation (ports 80/443, domains only, no private IPs)
→ HTTP/2 stream handler with FGN padding
→ Internet
3.3. FGN Padding
Structured padding that mimics real HTTP/2 traffic:
•	70% compressed content (gzip-like byte distribution)
•	20% text content (ASCII printable)
•	10% headers (HPACK codes)
Adaptive padding sizes per content type: HTML 200-800B, Image 50-200B, Font 100-400B, JSON 50-150B.
________________________________________
4. Connection Protocol
1.	DNS warmup — Phantom DNS queries to legend + popular domains
2.	TCP connection — VPS:443 via ConnectionManager pool
3.	TLS 1.3 handshake — Chrome-compatible parameters, ExportKeyingMaterial
4.	MARKER — SHA256(ekm || timeSlot)[:2], const-time verification, ±60s window
5.	Protocol version — 0x04
6.	Seed + LengthNonce — 32 + 24 bytes, crypto/rand
7.	Target address — Validated (ports 80/443, domains, no private IPs)
8.	HTTP/2 preface + GME dialog with HMAC
9.	Data Stream — FGN padding, WINDOW_UPDATE, half-close semantics
10.	Key Update — Poisson process (λ=5min)
Error Handling
Error Type	Server Response
Invalid MARKER	GOAWAY PROTOCOL_ERROR + jitter 3-100ms
Invalid HMAC	GOAWAY PROTOCOL_ERROR + jitter 3-100ms
Duress connection	Fake login page
Network error	Fail-closed (no response)
Target address violation	Fail-closed
Frame too large (>65535)	GOAWAY FRAME_SIZE_ERROR
________________________________________
5. Cryptographic Architecture
Key Derivation
text
PSK (32 bytes, []byte)
  ├─ HKDF(salt="veil-v1.1-marker-key") → marker_key (32 bytes)
  ├─ HKDF(salt="veil-v1.1-auth-key")   → auth_key (32 bytes)
  └─ HKDF(salt="veil-v1.1-marker-key") → duressMarkerKey (32 bytes)
ExportKeyingMaterial (RFC 5705)
text
ekm = tlsConn.ExportKeyingMaterial("veil-auth", nil, 32)
Replaces SessionID/TLSUnique. Identical on client and server. Used for both MARKER and HMAC.
MARKER
text
marker = SHA256(ekm || timeSlotStr)[:2]
16-bit value, ±60 second window, const-time verification of all 5 slots.
Authentication (D-019 v2)
text
normal_hmac = HMAC-SHA256(auth_key, ekm)[:16]
duress_hmac = HMAC-SHA256(auth_key, ekm || ":duress:" || duressCode)[:16]
128-bit HMAC tag (NIST SP 800-107). Embedded in GME frames: GREASE (4+4 bytes) + PING (8 bytes).
FGN Stream Cipher
text
ChaCha20 (RFC 8439)
  key = seed (32 bytes, crypto/rand)
  nonce = 24 bytes (XChaCha20)

Length encryption:
  lengthKey = SHA256(seed || "veil-length")
  Per-stream isolation via Fork(streamID)
Cryptographic Primitives
Primitive	Standard	Implementation
HKDF	RFC 5869	x/crypto/hkdf
HMAC-SHA256	FIPS 198-1	crypto/hmac
ChaCha20	RFC 8439	x/crypto/chacha20
TLS 1.3	RFC 8446	crypto/tls
ExportKeyingMaterial	RFC 5705	crypto/tls
________________________________________
6. Generative Mimicry Engine
The GME creates unique browser-like behavior for each session:
•	5 GME dialog models — Varied HTTP/2 frame sequences
•	Phantom traffic — Background requests simulating browser activity
•	Poison Pill Engine — Fake protocol signatures (WebRTC, game traffic)
•	Flaw Injection — 0.5% "human errors" in phantom requests
•	Degradation Mode — Simulates poor network conditions
•	Browser Fingerprint Diversity — Different User-Agent and GREASE per session
________________________________________
7. Security Metrics
Component	Protection
ExportKeyingMaterial	Symmetric HMAC parameters
Certificate pinning	MITM detection
Const-time MARKER	Timing attack prevention
GOAWAY jitter	Error timing signature
Rate limiter	Brute-force protection
Target address validation	SSRF prevention
In-memory PSK clearing	Forensics protection
Binary obfuscation	Reverse engineering
Anti-debugging	Dynamic analysis protection
Heap scrubbing	Memory forensics
eBPF TCP options	Passive TCP fingerprint
ConnectionManager R14	Connection lifecycle, race prevention
Half-close semantics	Data loss prevention
Idle timeout	Resource cleanup
________________________________________
8. Known Limitations
Limitation	Impact
ECH not implemented	SNI visible
No forward secrecy for PSK	Past sessions decryptable if PSK compromised
JA3 = Go/Chrome-like	Extension order differs from native Chrome
TCP options without eBPF	Linux kernel default order
Single TCP connection pooling	Head-of-line blocking for heavy sites
No client-side fragmentation	Large frames may exceed protocol limits
________________________________________
9. Client Applications
Windows
•	Console: veil.exe --mode client --listen :1080 --target VPS:443
•	GUI: veil.exe --tray — system tray with settings
Android
•	APK with foreground service and persistent notification
•	SOCKS5 proxy at 127.0.0.1:1080
•	Survives app switching and screen lock
Linux
•	Console client, same as Windows console mode

